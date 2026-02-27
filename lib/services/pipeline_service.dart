import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../models/video_info.dart';
import 'audio_service.dart';
import 'asr_service.dart';
import 'claude_service.dart';
import 'download_service.dart';

/// Callback for pipeline status changes.
typedef PipelineStatusCallback = void Function(
  PipelineStatus status,
  String message,
);

/// Callback for download progress within the pipeline.
typedef PipelineProgressCallback = void Function(
  double progress,
  String message,
);

/// Service that orchestrates the full video analysis pipeline:
/// Download -> Extract Audio -> ASR Transcription -> Claude Summary.
///
/// Manages temporary files and provides status callbacks at each stage.
class PipelineService extends GetxService {
  late final DownloadService _downloadService;
  late final AudioService _audioService;
  late final AsrService _asrService;
  late final ClaudeService _claudeService;

  @override
  void onInit() {
    super.onInit();
    _downloadService = Get.find<DownloadService>();
    _audioService = Get.find<AudioService>();
    _asrService = Get.find<AsrService>();
    _claudeService = Get.find<ClaudeService>();
  }

  /// Runs the full analysis pipeline for a Douyin video.
  ///
  /// [inputText] - The raw text containing a Douyin share link.
  /// [cookiesFile] - Optional path to a cookies file for yt-dlp.
  /// [onStatusChanged] - Callback for pipeline stage transitions.
  /// [onDownloadProgress] - Callback for download progress updates.
  ///
  /// Returns a [VideoInfo] populated with all available data.
  ///
  /// On failure, throws a [PipelineException] with details about which
  /// stage failed and why. Temporary files are cleaned up regardless
  /// of success or failure.
  Future<VideoInfo> process({
    required String inputText,
    String? cookiesFile,
    PipelineStatusCallback? onStatusChanged,
    PipelineProgressCallback? onDownloadProgress,
  }) async {
    // Extract URL from input text
    final url = _downloadService.extractUrl(inputText);
    if (url == null) {
      throw PipelineException(
        stage: PipelineStatus.error,
        message: 'No valid URL found in the input text. '
            'Please paste a Douyin share link.',
      );
    }

    // Create a unique working directory for this pipeline run
    final workDir = await _createWorkDir();

    try {
      // Stage 1: Download video (also retrieves metadata via HTTP)
      onStatusChanged?.call(PipelineStatus.downloading, 'Downloading video...');

      // Get metadata first (title, author, tags come from the same HTTP request)
      Map<String, dynamic> metadata = {};
      try {
        metadata = await _downloadService.getVideoMetadata(url);
      } catch (_) {
        // Metadata is best-effort; continue even if it fails
      }

      final videoPath = await _downloadService.downloadVideo(
        url: url,
        outputDir: workDir,
        onProgress: onDownloadProgress != null
            ? (progress, status) => onDownloadProgress(progress, status)
            : null,
      );

      // Stage 2: Extract audio
      onStatusChanged?.call(
          PipelineStatus.extractingAudio, 'Extracting audio from video...');

      final audioPath = await _audioService.extractAudio(
        videoPath: videoPath,
        outputDir: workDir,
      );

      // Stage 3: ASR transcription
      onStatusChanged?.call(
          PipelineStatus.transcribing, 'Transcribing audio to text...');

      final transcription = await _asrService.transcribe(
        audioPath: audioPath,
      );

      // Stage 4: Claude summary
      onStatusChanged?.call(
          PipelineStatus.summarizing, 'Generating AI summary...');

      final title = metadata['title'] as String?;
      final author = metadata['author'] as String?;
      final tags = (metadata['tags'] as List<String>?) ?? const <String>[];

      final summary = await _claudeService.generateSummary(
        transcription: transcription,
        title: title,
        author: author,
        tags: tags,
      );

      // Stage 5: Clean up temporary files and complete
      await _cleanupWorkDir(workDir);
      onStatusChanged?.call(PipelineStatus.completed, 'Analysis complete!');

      return VideoInfo(
        url: url,
        title: title,
        author: author,
        transcription: transcription,
        summary: summary,
        tags: tags,
        createdAt: DateTime.now(),
      );
    } on DownloadException catch (e) {
      onStatusChanged?.call(PipelineStatus.error, e.message);
      await _cleanupWorkDir(workDir);
      throw PipelineException(
        stage: PipelineStatus.downloading,
        message: e.message,
        details: e.details,
      );
    } on AudioExtractionException catch (e) {
      onStatusChanged?.call(PipelineStatus.error, e.message);
      await _cleanupWorkDir(workDir);
      throw PipelineException(
        stage: PipelineStatus.extractingAudio,
        message: e.message,
        details: e.details,
      );
    } on TranscriptionException catch (e) {
      onStatusChanged?.call(PipelineStatus.error, e.message);
      await _cleanupWorkDir(workDir);
      throw PipelineException(
        stage: PipelineStatus.transcribing,
        message: e.message,
        details: e.details,
      );
    } on ClaudeException catch (e) {
      onStatusChanged?.call(PipelineStatus.error, e.message);
      await _cleanupWorkDir(workDir);
      throw PipelineException(
        stage: PipelineStatus.summarizing,
        message: e.message,
        details: e.details,
      );
    } catch (e) {
      onStatusChanged?.call(PipelineStatus.error, e.toString());
      await _cleanupWorkDir(workDir);
      throw PipelineException(
        stage: PipelineStatus.error,
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Creates a unique temporary working directory for a pipeline run.
  Future<String> _createWorkDir() async {
    final baseDir = AppConstants.workDir;
    final base = Directory(baseDir);
    if (!await base.exists()) {
      await base.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final workDir = p.join(baseDir, 'run_$timestamp');
    await Directory(workDir).create(recursive: true);
    return workDir;
  }

  /// Removes the working directory and all its contents.
  ///
  /// Silently ignores errors (e.g., directory already deleted).
  Future<void> _cleanupWorkDir(String workDir) async {
    try {
      final dir = Directory(workDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; don't propagate errors
    }
  }

  /// Cleans up all pipeline run directories in the work directory.
  ///
  /// Useful for freeing disk space. Call this periodically or from
  /// a settings/maintenance screen.
  Future<int> cleanupAllRuns() async {
    var deletedCount = 0;
    try {
      final baseDir = Directory(AppConstants.workDir);
      if (!await baseDir.exists()) return 0;

      await for (final entity in baseDir.list()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith('run_')) {
          await entity.delete(recursive: true);
          deletedCount++;
        }
      }
    } catch (_) {
      // Best-effort cleanup
    }
    return deletedCount;
  }
}

/// Exception thrown when any stage of the pipeline fails.
class PipelineException implements Exception {
  /// Which pipeline stage failed.
  final PipelineStatus stage;

  /// Human-readable error message.
  final String message;

  /// Optional detailed error information (e.g., stderr output).
  final String? details;

  PipelineException({
    required this.stage,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    final stageName = stage.name;
    if (details != null && details!.isNotEmpty) {
      return 'PipelineException [$stageName]: $message\nDetails: $details';
    }
    return 'PipelineException [$stageName]: $message';
  }
}
