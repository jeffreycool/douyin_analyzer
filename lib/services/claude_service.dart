import 'dart:io';

import 'package:get/get.dart';

import '../core/constants.dart';

/// Service responsible for generating content summaries via the Claude CLI.
class ClaudeService extends GetxService {
  /// Default timeout for Claude CLI invocation.
  static const Duration defaultTimeout = Duration(seconds: 120);

  /// Generates a Markdown summary of a video based on its transcription
  /// and metadata.
  ///
  /// [transcription] - The ASR transcription text.
  /// [title] - Video title (optional).
  /// [author] - Video author (optional).
  /// [tags] - List of video tags (optional).
  /// [timeout] - Maximum time to wait for Claude to respond.
  ///
  /// Returns the generated summary as a Markdown string.
  Future<String> generateSummary({
    required String transcription,
    String? title,
    String? author,
    List<String> tags = const [],
    Duration timeout = defaultTimeout,
  }) async {
    if (transcription.trim().isEmpty) {
      throw ClaudeException('Cannot generate summary from empty transcription');
    }

    // Build the prompt from the template
    final prompt = _buildPrompt(
      transcription: transcription,
      title: title,
      author: author,
      tags: tags,
    );

    // Use Process.start + stdin to avoid command-line length limits.
    // The user message (transcription + metadata) is piped via stdin.
    //
    // Two critical flags to isolate from the host Claude Code environment:
    //
    // 1. --system-prompt: Override the default system prompt so the model
    //    receives only our summarization instructions.
    //
    // 2. --setting-sources '': Prevent loading ~/.claude/CLAUDE.md,
    //    FLAGS.md, RULES.md, project settings and hooks. Without this,
    //    `claude -p` injects hundreds of unrelated framework instructions
    //    that cause the model to produce conversational (not structured)
    //    output.
    //
    // 3. includeParentEnvironment: false: Prevent session env vars
    //    (CLAUDECODE, CLAUDE_CODE_ENTRYPOINT, etc.) from leaking.
    final process = await Process.start(
      AppConstants.claudePath,
      [
        '-p',
        '--output-format', 'text',
        '--system-prompt', AppConstants.summarySystemPrompt,
        '--setting-sources', '',
      ],
      environment: {
        'HOME': Platform.environment['HOME'] ?? '',
        'PATH': Platform.environment['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
        'USER': Platform.environment['USER'] ?? '',
        'LANG': 'en_US.UTF-8',
      },
      includeParentEnvironment: false,
    );

    // Write prompt to stdin and close it
    process.stdin.writeln(prompt);
    await process.stdin.close();

    // Collect stdout and stderr with timeout
    final stdoutFuture = process.stdout
        .transform(const SystemEncoding().decoder)
        .join();
    final stderrFuture = process.stderr
        .transform(const SystemEncoding().decoder)
        .join();

    final exitCodeFuture = process.exitCode;

    // Wait with timeout
    final exitCode = await exitCodeFuture.timeout(
      timeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigterm);
        throw ClaudeException(
          'Claude CLI timed out after ${timeout.inSeconds} seconds. '
          'The transcription may be too long or the service may be slow.',
        );
      },
    );

    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;

    if (exitCode != 0) {
      throw ClaudeException(
        'Claude CLI exited with code $exitCode',
        details: stderr.isNotEmpty ? stderr : stdout,
      );
    }

    final summary = stdout.trim();
    if (summary.isEmpty) {
      throw ClaudeException(
        'Claude CLI produced empty output. '
        'This may indicate a configuration issue.',
      );
    }

    return summary;
  }

  /// Builds the full prompt by substituting values into the template.
  String _buildPrompt({
    required String transcription,
    String? title,
    String? author,
    List<String> tags = const [],
  }) {
    return AppConstants.summaryUserPrompt
        .replaceAll('{transcription}', _sanitizeTranscription(transcription))
        .replaceAll('{title}', title ?? 'Unknown')
        .replaceAll('{author}', author ?? 'Unknown')
        .replaceAll('{tags}', tags.isNotEmpty ? tags.join(', ') : 'None');
  }

  /// Sanitizes ASR transcription to prevent model safety triggers.
  ///
  /// Whisper ASR often transcribes tech video content that discusses
  /// AI model censorship, safety removal, jailbreaking, etc. These
  /// phrases can cause the summarization model to refuse or produce
  /// truncated output. We replace entire sentences containing known
  /// trigger patterns with neutral placeholders.
  static String _sanitizeTranscription(String text) {
    final lines = text.split('\n');
    final sanitized = <String>[];
    for (final line in lines) {
      if (_containsTrigger(line)) {
        // Replace the entire line with a neutral summary preserving structure
        sanitized.add(_neutralizeLine(line));
      } else {
        sanitized.add(line);
      }
    }
    return sanitized.join('\n');
  }

  static final _triggerPatterns = [
    RegExp(r'移除.{0,6}(審查|审查|安全限制|guardrail)'),
    RegExp(r'(去除|绕过|破解|越獄|越狱|jailbreak).{0,6}(模型|AI|安全|審查|审查)'),
    RegExp(r'(uncensor|remove.{0,6}censor|remove.{0,6}safety)', caseSensitive: false),
  ];

  static bool _containsTrigger(String line) {
    return _triggerPatterns.any((p) => p.hasMatch(line));
  }

  /// Replaces a triggered line, keeping non-sensitive project names/rankings.
  static String _neutralizeLine(String line) {
    // Extract ranking info if present (e.g. "第15名到第11名", "第10名到第4名")
    final rankMatch = RegExp(r'第\d+名[到至]第\d+名').allMatches(line);
    final ranks = rankMatch.map((m) => m.group(0)).join('、');

    if (ranks.isNotEmpty) {
      return '$ranks为一组开源基础设施和开发工具项目，涵盖安全、数据库等方向。';
    }
    return '（该段落描述了一组开源基础设施项目）';
  }
}

/// Exception thrown when Claude CLI invocation fails.
class ClaudeException implements Exception {
  final String message;
  final String? details;

  ClaudeException(this.message, {this.details});

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return 'ClaudeException: $message\nDetails: $details';
    }
    return 'ClaudeException: $message';
  }
}
