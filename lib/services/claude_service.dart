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
    // The prompt can be very long (full transcription text), so passing it
    // as a CLI argument could hit OS argument length limits (~262144 bytes
    // on macOS). Instead, pipe the prompt via stdin:
    //   echo <prompt> | claude -p --output-format text
    //
    // When `claude -p` receives no prompt argument, it reads from stdin.
    final process = await Process.start(
      AppConstants.claudePath,
      [
        '-p',
        '--output-format', 'text',
      ],
      environment: {
        // Prevent nested session detection if running inside Claude Code
        'CLAUDECODE': '',
      },
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
    return AppConstants.summaryPrompt
        .replaceAll('{transcription}', transcription)
        .replaceAll('{title}', title ?? 'Unknown')
        .replaceAll('{author}', author ?? 'Unknown')
        .replaceAll('{tags}', tags.isNotEmpty ? tags.join(', ') : 'None');
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
