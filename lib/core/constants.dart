import 'dart:io';
import 'package:path/path.dart' as p;

class AppConstants {
  static const String appName = 'Douyin Analyzer';

  // Tool paths (Homebrew on Apple Silicon)
  static const String ytDlpPath = '/opt/homebrew/bin/yt-dlp';
  static const String ffmpegPath = '/opt/homebrew/bin/ffmpeg';
  static const String whisperCliPath = '/opt/homebrew/bin/whisper-cli';
  static const String claudePath = '/Users/jeffrey/.local/bin/claude';

  // Whisper model
  static String get whisperModelPath =>
      p.join(Platform.environment['HOME'] ?? '/Users/jeffrey',
          '.local/share/whisper-models/ggml-base.bin');

  // Working directory for temp files
  static String get workDir =>
      p.join(Platform.environment['HOME'] ?? '/Users/jeffrey',
          '.douyin_analyzer');

  // Claude prompt template
  static const String summaryPrompt = '''
You are a video content analyst. Based on the following audio transcription from a Douyin short video, generate a comprehensive content summary document in Chinese (Markdown format).

Requirements:
1. Video overview (1-2 sentences)
2. Key points (bullet list)
3. Technical details mentioned (if any)
4. Conclusion/takeaway

Transcription:
---
{transcription}
---

Video metadata:
- Title: {title}
- Author: {author}
- Tags: {tags}

Please output the summary in well-structured Chinese Markdown.''';
}
