import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../models/video_info.dart';

/// Persists analysis history as a JSON file.
///
/// Storage location: ~/.douyin_analyzer/history.json
class HistoryService extends GetxService {
  late final String _historyPath;

  @override
  void onInit() {
    super.onInit();
    _historyPath = p.join(AppConstants.workDir, 'history.json');
  }

  /// Loads all saved history entries, newest first.
  Future<List<VideoInfo>> loadHistory() async {
    try {
      final file = File(_historyPath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => VideoInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the full history list to disk.
  Future<void> saveHistory(List<VideoInfo> items) async {
    final file = File(_historyPath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final json = items.map((e) => e.toJson()).toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  /// Appends a single item to the front of history and saves.
  Future<void> addEntry(VideoInfo item) async {
    final items = await loadHistory();
    items.insert(0, item);
    await saveHistory(items);
  }

  /// Removes a single entry by matching URL + createdAt, then saves.
  Future<void> removeEntry(VideoInfo item) async {
    final items = await loadHistory();
    items.removeWhere((e) =>
        e.url == item.url &&
        e.createdAt?.toIso8601String() == item.createdAt?.toIso8601String());
    await saveHistory(items);
  }

  /// Clears all history.
  Future<void> clearAll() async {
    final file = File(_historyPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
