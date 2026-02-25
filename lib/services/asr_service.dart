import 'dart:io';

import 'package:get/get.dart';

import '../core/constants.dart';

/// Service responsible for speech-to-text transcription using whisper-cli.
class AsrService extends GetxService {
  /// Transcribes the audio file at [audioPath] to text using whisper-cli.
  ///
  /// [audioPath] - Absolute path to a WAV file (16kHz, mono recommended).
  ///
  /// Returns the transcribed text as a string.
  Future<String> transcribe({
    required String audioPath,
  }) async {
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw TranscriptionException(
        'Audio file not found: $audioPath',
      );
    }

    // Verify whisper model exists
    final modelPath = AppConstants.whisperModelPath;
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      throw TranscriptionException(
        'Whisper model not found: $modelPath. '
        'Please download the model first.',
      );
    }

    // whisper-cli command:
    //   -m model.bin       : model path
    //   -l zh              : language hint (Chinese)
    //   -otxt              : output as plain text
    //   -f audio.wav       : input file
    //   --no-timestamps    : omit timestamps for cleaner text
    final result = await Process.run(
      AppConstants.whisperCliPath,
      [
        '-m', modelPath,
        '-l', 'zh',
        '-otxt',
        '--no-timestamps',
        '-f', audioPath,
      ],
      stderrEncoding: const SystemEncoding(),
      stdoutEncoding: const SystemEncoding(),
      // Whisper can take a while for long audio
      // 10 minutes should be more than enough for short videos
    );

    if (result.exitCode != 0) {
      throw TranscriptionException(
        'whisper-cli exited with code ${result.exitCode}',
        details: result.stderr.toString(),
      );
    }

    // whisper-cli with -otxt produces a .txt file alongside the input
    // e.g., audio.wav -> audio.wav.txt
    final txtPath = '$audioPath.txt';
    final txtFile = File(txtPath);

    String transcription;

    if (await txtFile.exists()) {
      // Read from the output text file
      transcription = await txtFile.readAsString();
    } else {
      // Fallback: some versions of whisper-cli output to stdout
      transcription = result.stdout.toString();
    }

    transcription = _cleanTranscription(transcription);

    if (transcription.isEmpty) {
      throw TranscriptionException(
        'Whisper produced empty transcription. '
        'The audio may be silent or too short.',
      );
    }

    return transcription;
  }

  /// Cleans up the raw transcription text.
  ///
  /// Removes common whisper artifacts like [BLANK_AUDIO], extra whitespace,
  /// and leading/trailing newlines.
  String _cleanTranscription(String raw) {
    var cleaned = raw;

    // Remove common whisper artifacts
    cleaned = cleaned.replaceAll(RegExp(r'\[BLANK_AUDIO\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[MUSIC\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[APPLAUSE\]'), '');

    // Collapse multiple whitespace/newlines into single space
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }
}

/// Exception thrown when speech-to-text transcription fails.
class TranscriptionException implements Exception {
  final String message;
  final String? details;

  TranscriptionException(this.message, {this.details});

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return 'TranscriptionException: $message\nDetails: $details';
    }
    return 'TranscriptionException: $message';
  }
}
