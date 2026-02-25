import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/video_info.dart';
import '../services/pipeline_service.dart';

class HomeController extends GetxController {
  final status = PipelineStatus.idle.obs;
  final currentVideo = Rx<VideoInfo?>(null);
  final errorMessage = ''.obs;
  final progressMessage = ''.obs;
  final history = <VideoInfo>[].obs;

  final urlController = TextEditingController();

  bool get isProcessing =>
      status.value != PipelineStatus.idle &&
      status.value != PipelineStatus.completed &&
      status.value != PipelineStatus.error;

  /// Extract the first URL from pasted text (handles Douyin share text).
  String? _extractUrl(String text) {
    final urlPattern = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text.trim());
    return match?.group(0);
  }

  /// Main processing pipeline entry point.
  Future<void> processUrl(String rawInput) async {
    final url = _extractUrl(rawInput);
    if (url == null || url.isEmpty) {
      errorMessage.value = 'No valid URL found in the input text.';
      return;
    }

    // Reset state
    errorMessage.value = '';
    progressMessage.value = 'Preparing...';
    status.value = PipelineStatus.downloading;
    currentVideo.value = null;

    try {
      final pipelineService = Get.find<PipelineService>();

      final result = await pipelineService.process(
        inputText: url,
        onStatusChanged: (newStatus, message) {
          status.value = newStatus;
          progressMessage.value = message;
        },
      );

      currentVideo.value = result;
      status.value = PipelineStatus.completed;
      progressMessage.value = 'Analysis complete!';

      // Add to history
      history.insert(0, result);

      // Navigate to result page
      Get.toNamed('/result');
    } catch (e) {
      status.value = PipelineStatus.error;
      errorMessage.value = e.toString();
      progressMessage.value = '';
    }
  }

  /// Copy the given text to the system clipboard.
  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'Content copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Clear all history entries.
  void clearHistory() {
    history.clear();
  }

  /// Load a history item and navigate to result page.
  void viewHistoryItem(VideoInfo item) {
    currentVideo.value = item;
    status.value = PipelineStatus.completed;
    Get.toNamed('/result');
  }

  /// Reset the pipeline to idle state for a new analysis.
  void resetForNewAnalysis() {
    status.value = PipelineStatus.idle;
    currentVideo.value = null;
    errorMessage.value = '';
    progressMessage.value = '';
    urlController.clear();
  }

  @override
  void onClose() {
    urlController.dispose();
    super.onClose();
  }
}
