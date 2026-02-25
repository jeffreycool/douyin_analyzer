import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';

/// Service responsible for extracting audio from video files using FFmpeg.
class AudioService extends GetxService {
  /// Extracts audio from [videoPath] and saves it as a WAV file suitable
  /// for whisper-cli input (16kHz, mono).
  ///
  /// [videoPath] - Absolute path to the source video file.
  /// [outputDir] - Directory where the WAV file will be saved.
  ///               If null, uses the same directory as the video.
  ///
  /// Returns the absolute path to the extracted WAV file.
  Future<String> extractAudio({
    required String videoPath,
    String? outputDir,
  }) async {
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw AudioExtractionException(
        'Video file not found: $videoPath',
      );
    }

    final targetDir = outputDir ?? p.dirname(videoPath);
    final outputPath = p.join(targetDir, 'audio.wav');

    // Ensure output directory exists
    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Remove existing output file to avoid ffmpeg prompt
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    // FFmpeg command:
    //   -i input.mp4       : input file
    //   -ar 16000          : 16kHz sample rate (whisper optimal)
    //   -ac 1              : mono channel (whisper optimal)
    //   -f wav             : WAV output format
    //   -y                 : overwrite without asking
    final result = await Process.run(
      AppConstants.ffmpegPath,
      [
        '-i', videoPath,
        '-ar', '16000',
        '-ac', '1',
        '-f', 'wav',
        '-y',
        outputPath,
      ],
      // FFmpeg writes progress to stderr, so we capture it
      stderrEncoding: const SystemEncoding(),
      stdoutEncoding: const SystemEncoding(),
    );

    if (result.exitCode != 0) {
      throw AudioExtractionException(
        'FFmpeg exited with code ${result.exitCode}',
        details: result.stderr.toString(),
      );
    }

    // Verify output file was created and is not empty
    if (!await outputFile.exists()) {
      throw AudioExtractionException(
        'FFmpeg completed but output file was not created: $outputPath',
      );
    }

    final fileSize = await outputFile.length();
    if (fileSize == 0) {
      await outputFile.delete();
      throw AudioExtractionException(
        'FFmpeg produced an empty audio file. The video may have no audio track.',
      );
    }

    return outputPath;
  }
}

/// Exception thrown when audio extraction fails.
class AudioExtractionException implements Exception {
  final String message;
  final String? details;

  AudioExtractionException(this.message, {this.details});

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return 'AudioExtractionException: $message\nDetails: $details';
    }
    return 'AudioExtractionException: $message';
  }
}
