import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';

/// Callback for download progress updates.
/// [progress] is a value between 0.0 and 1.0, or -1 if indeterminate.
/// [status] is a human-readable status string.
typedef DownloadProgressCallback = void Function(
    double progress, String status);

/// Service responsible for parsing Douyin share links and downloading videos
/// via yt-dlp.
class DownloadService extends GetxService {
  /// Extracts the first URL from a text string (e.g. Douyin share message).
  ///
  /// Douyin share texts typically look like:
  ///   "5.38 lPm:/ 复制打开抖音... https://v.douyin.com/xxxxx/"
  /// This method grabs the https URL from that text.
  String? extractUrl(String text) {
    final urlPattern = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text.trim());
    return match?.group(0);
  }

  /// Downloads a Douyin video to [outputDir] using yt-dlp.
  ///
  /// Returns the absolute path to the downloaded video file.
  ///
  /// [url] - The Douyin video URL (short link or full URL).
  /// [outputDir] - Directory where the video will be saved.
  /// [cookiesFile] - Optional path to a Netscape-format cookies file.
  /// [onProgress] - Optional callback for progress reporting.
  Future<String> downloadVideo({
    required String url,
    required String outputDir,
    String? cookiesFile,
    DownloadProgressCallback? onProgress,
  }) async {
    // Ensure output directory exists
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Build output template: video saved as "video.<ext>"
    final outputTemplate = p.join(outputDir, 'video.%(ext)s');

    final args = <String>[
      // Follow redirects (handles short links like v.douyin.com/xxx)
      '--no-check-certificates',
      // Force best mp4 format
      '-f', 'best[ext=mp4]/best',
      // Output template
      '-o', outputTemplate,
      // Overwrite existing files
      '--force-overwrites',
      // No playlist
      '--no-playlist',
      // Print progress to stdout for parsing
      '--newline',
    ];

    // Add cookies if provided
    if (cookiesFile != null && cookiesFile.isNotEmpty) {
      final cookieFile = File(cookiesFile);
      if (await cookieFile.exists()) {
        args.addAll(['--cookies', cookiesFile]);
      }
    }

    args.add(url);

    onProgress?.call(-1, 'Starting download...');

    final process = await Process.start(
      AppConstants.ytDlpPath,
      args,
      workingDirectory: outputDir,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    // Parse yt-dlp stdout for progress information
    process.stdout
        .transform(const SystemEncoding().decoder)
        .listen((data) {
      stdoutBuffer.write(data);
      _parseProgress(data, onProgress);
    });

    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((data) {
      stderrBuffer.write(data);
    });

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      final stderr = stderrBuffer.toString();
      throw DownloadException(
        'yt-dlp exited with code $exitCode',
        details: stderr.isNotEmpty ? stderr : stdoutBuffer.toString(),
      );
    }

    onProgress?.call(1.0, 'Download complete');

    // Find the downloaded file
    final downloadedFile = await _findDownloadedVideo(outputDir);
    if (downloadedFile == null) {
      throw DownloadException(
        'Download appeared to succeed but no video file found in $outputDir',
      );
    }

    return downloadedFile;
  }

  /// Parses yt-dlp stdout lines to extract download progress.
  ///
  /// yt-dlp progress lines look like:
  ///   [download]  45.2% of  12.34MiB at  1.23MiB/s ETA 00:08
  void _parseProgress(String data, DownloadProgressCallback? onProgress) {
    if (onProgress == null) return;

    final lines = data.split('\n');
    for (final line in lines) {
      // Match percentage pattern
      final percentMatch = RegExp(r'\[download\]\s+([\d.]+)%').firstMatch(line);
      if (percentMatch != null) {
        final percent = double.tryParse(percentMatch.group(1) ?? '');
        if (percent != null) {
          onProgress(percent / 100.0, line.trim());
          continue;
        }
      }

      // Report non-empty status lines
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
        onProgress(-1, trimmed);
      }
    }
  }

  /// Scans [directory] for the downloaded video file.
  ///
  /// Returns the path to the first video file found, or null.
  Future<String?> _findDownloadedVideo(String directory) async {
    final dir = Directory(directory);
    const videoExtensions = {'.mp4', '.mkv', '.webm', '.flv', '.avi', '.mov'};

    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (videoExtensions.contains(ext)) {
          return entity.path;
        }
      }
    }
    return null;
  }
}

/// Exception thrown when video download fails.
class DownloadException implements Exception {
  final String message;
  final String? details;

  DownloadException(this.message, {this.details});

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return 'DownloadException: $message\nDetails: $details';
    }
    return 'DownloadException: $message';
  }
}
