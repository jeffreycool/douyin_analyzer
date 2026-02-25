import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Callback for download progress updates.
/// [progress] is a value between 0.0 and 1.0, or -1 if indeterminate.
/// [status] is a human-readable status string.
typedef DownloadProgressCallback = void Function(
    double progress, String status);

/// Service responsible for parsing Douyin share links and downloading videos
/// via direct HTTP requests (no yt-dlp dependency).
///
/// Technical approach (based on douyin-mcp-server):
/// 1. Follow short link redirect → extract video_id
/// 2. Fetch iesdouyin.com share page → parse embedded JSON
/// 3. Extract watermark-free video URL (replace "playwm" → "play")
/// 4. Download video file via HTTP GET
class DownloadService extends GetxService {
  static const _mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/16.6 Mobile/15E148 Safari/604.1';

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

  /// Resolves a Douyin short link and extracts the video ID.
  ///
  /// Short links like `https://v.douyin.com/xxxxx/` redirect to
  /// `https://www.douyin.com/video/{video_id}?...`
  Future<String> _resolveVideoId(String shareUrl) async {
    final client = HttpClient()
      ..userAgent = _mobileUserAgent;

    try {
      // Disable auto-redirect to manually follow and capture final URL
      client.autoUncompress = true;
      final request = await client.getUrl(Uri.parse(shareUrl));
      request.followRedirects = false;
      request.headers.set('User-Agent', _mobileUserAgent);

      var response = await request.close();
      var redirectUrl = shareUrl;

      // Follow redirects manually (up to 10 hops)
      var redirectCount = 0;
      while (response.isRedirect && redirectCount < 10) {
        final location = response.headers.value('location');
        if (location == null) break;

        // Handle relative redirects
        final nextUrl = Uri.parse(redirectUrl).resolve(location).toString();
        redirectUrl = nextUrl;

        final nextRequest = await client.getUrl(Uri.parse(nextUrl));
        nextRequest.followRedirects = false;
        nextRequest.headers.set('User-Agent', _mobileUserAgent);
        response = await nextRequest.close();
        redirectCount++;
      }

      // Drain the response body
      await response.drain<void>();

      // Extract video_id from the final URL
      // Final URL looks like: https://www.douyin.com/video/7321234567890123456?...
      final finalUri = Uri.parse(redirectUrl);
      final pathSegments = finalUri.pathSegments
          .where((s) => s.isNotEmpty)
          .toList();

      // Try to find a numeric ID in path segments
      for (final segment in pathSegments.reversed) {
        if (RegExp(r'^\d{15,}$').hasMatch(segment)) {
          return segment;
        }
      }

      // Fallback: try to extract from the last path segment
      final lastSegment = pathSegments.isNotEmpty ? pathSegments.last : '';
      final idMatch = RegExp(r'(\d{15,})').firstMatch(lastSegment);
      if (idMatch != null) {
        return idMatch.group(1)!;
      }

      throw DownloadException(
        'Could not extract video ID from redirect URL: $redirectUrl',
      );
    } finally {
      client.close();
    }
  }

  /// Fetches video metadata and watermark-free download URL from iesdouyin.com.
  ///
  /// Returns a map with keys: 'videoUrl', 'title', 'author', 'tags'.
  Future<Map<String, dynamic>> fetchVideoInfo(String videoId) async {
    final sharePageUrl = 'https://www.iesdouyin.com/share/video/$videoId';

    final response = await http.get(
      Uri.parse(sharePageUrl),
      headers: {
        'User-Agent': _mobileUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://www.douyin.com/',
      },
    );

    if (response.statusCode != 200) {
      throw DownloadException(
        'Failed to fetch video page (HTTP ${response.statusCode})',
        details: 'URL: $sharePageUrl',
      );
    }

    final html = response.body;

    // Extract embedded JSON from window._ROUTER_DATA
    final routerDataPattern = RegExp(
      r'window\._ROUTER_DATA\s*=\s*(.*?)</script>',
      dotAll: true,
    );
    final routerMatch = routerDataPattern.firstMatch(html);

    if (routerMatch == null) {
      // Fallback: try RENDER_DATA pattern (older pages)
      return _tryRenderDataFallback(html, videoId);
    }

    try {
      final jsonStr = routerMatch.group(1)!.trim();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Look for video data in loaderData
      final loaderData = data['loaderData'] as Map<String, dynamic>?;
      if (loaderData == null) {
        throw DownloadException('No loaderData found in page JSON');
      }

      // Try different key patterns
      Map<String, dynamic>? pageData;
      for (final key in loaderData.keys) {
        if (key.contains('video_') || key.contains('note_')) {
          pageData = loaderData[key] as Map<String, dynamic>?;
          break;
        }
      }

      // Fallback: try first available page data
      pageData ??= loaderData.values
          .whereType<Map<String, dynamic>>()
          .firstOrNull;

      if (pageData == null) {
        throw DownloadException('No page data found in loaderData');
      }

      return _extractVideoData(pageData, videoId);
    } catch (e) {
      if (e is DownloadException) rethrow;
      throw DownloadException(
        'Failed to parse video page JSON',
        details: e.toString(),
      );
    }
  }

  /// Extracts video URL and metadata from the parsed page data.
  Map<String, dynamic> _extractVideoData(
      Map<String, dynamic> pageData, String videoId) {
    // Navigate the nested structure to find video info
    // Structure varies, try multiple paths
    Map<String, dynamic>? videoDetail;

    // Path 1: videoInfoRes.item_list[0]
    final videoInfoRes = pageData['videoInfoRes'] as Map<String, dynamic>?;
    if (videoInfoRes != null) {
      final itemList = videoInfoRes['item_list'] as List<dynamic>?;
      if (itemList != null && itemList.isNotEmpty) {
        videoDetail = itemList[0] as Map<String, dynamic>;
      }
    }

    // Path 2: direct video key
    videoDetail ??= pageData['video'] as Map<String, dynamic>? ??
        pageData['aweme_detail'] as Map<String, dynamic>?;

    // Try to find video data recursively
    videoDetail ??= _findVideoInMap(pageData);

    if (videoDetail == null) {
      throw DownloadException(
        'Could not find video data in page response for video $videoId',
      );
    }

    // Extract the video play URL
    String? videoUrl;

    // Try: video.play_addr.url_list
    final video = videoDetail['video'] as Map<String, dynamic>?;
    if (video != null) {
      final playAddr = video['play_addr'] as Map<String, dynamic>?;
      if (playAddr != null) {
        final urlList = playAddr['url_list'] as List<dynamic>?;
        if (urlList != null && urlList.isNotEmpty) {
          videoUrl = urlList[0].toString();
        }
      }

      // Fallback: video.play_addr_lowbr
      if (videoUrl == null) {
        final playAddrLow =
            video['play_addr_lowbr'] as Map<String, dynamic>?;
        if (playAddrLow != null) {
          final urlList = playAddrLow['url_list'] as List<dynamic>?;
          if (urlList != null && urlList.isNotEmpty) {
            videoUrl = urlList[0].toString();
          }
        }
      }
    }

    if (videoUrl == null) {
      throw DownloadException(
        'Could not extract video URL from page data for video $videoId',
      );
    }

    // Remove watermark: replace "playwm" with "play"
    videoUrl = videoUrl.replaceAll('playwm', 'play');

    // Extract metadata
    final desc = videoDetail['desc'] as String? ?? '';
    final author = videoDetail['author'] as Map<String, dynamic>?;
    final authorName = author?['nickname'] as String? ?? '';

    final textExtra = videoDetail['text_extra'] as List<dynamic>?;
    final tags = textExtra
            ?.map((t) => (t as Map<String, dynamic>)['hashtag_name'] as String?)
            .where((t) => t != null && t.isNotEmpty)
            .cast<String>()
            .toList() ??
        <String>[];

    return {
      'videoUrl': videoUrl,
      'title': desc,
      'author': authorName,
      'tags': tags,
      'videoId': videoId,
    };
  }

  /// Searches for video data recursively in a map structure.
  Map<String, dynamic>? _findVideoInMap(Map<String, dynamic> data) {
    // Look for a map that contains 'video' and 'desc' keys (typical aweme structure)
    if (data.containsKey('video') &&
        data.containsKey('desc') &&
        data['video'] is Map) {
      return data;
    }

    for (final value in data.values) {
      if (value is Map<String, dynamic>) {
        final found = _findVideoInMap(value);
        if (found != null) return found;
      } else if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            final found = _findVideoInMap(item);
            if (found != null) return found;
          }
        }
      }
    }
    return null;
  }

  /// Fallback: try parsing RENDER_DATA from older page format.
  Map<String, dynamic> _tryRenderDataFallback(
      String html, String videoId) {
    final renderPattern = RegExp(
      r'<script\s+id="RENDER_DATA"\s+type="application/json">(.*?)</script>',
      dotAll: true,
    );
    final renderMatch = renderPattern.firstMatch(html);

    if (renderMatch == null) {
      throw DownloadException(
        'Could not find video data in page HTML (neither _ROUTER_DATA nor RENDER_DATA found)',
        details: 'Video ID: $videoId',
      );
    }

    try {
      final encoded = renderMatch.group(1)!.trim();
      final decoded = Uri.decodeComponent(encoded);
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      // Find the aweme detail in RENDER_DATA
      for (final value in data.values) {
        if (value is Map<String, dynamic>) {
          final awemeDetail =
              value['awemeDetail'] as Map<String, dynamic>?;
          if (awemeDetail != null) {
            return _extractVideoData({'aweme_detail': awemeDetail}, videoId);
          }
        }
      }

      throw DownloadException('No awemeDetail in RENDER_DATA');
    } catch (e) {
      if (e is DownloadException) rethrow;
      throw DownloadException(
        'Failed to parse RENDER_DATA',
        details: e.toString(),
      );
    }
  }

  /// Downloads a Douyin video to [outputDir].
  ///
  /// Returns the absolute path to the downloaded video file.
  ///
  /// [url] - The Douyin video URL (short link or full URL).
  /// [outputDir] - Directory where the video will be saved.
  /// [onProgress] - Optional callback for progress reporting.
  Future<String> downloadVideo({
    required String url,
    required String outputDir,
    String? cookiesFile, // kept for API compatibility
    DownloadProgressCallback? onProgress,
  }) async {
    // Ensure output directory exists
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    onProgress?.call(-1, 'Resolving video link...');

    // Step 1: Resolve short link → video ID
    final videoId = await _resolveVideoId(url);
    onProgress?.call(0.1, 'Video ID: $videoId');

    // Step 2: Fetch video info and download URL
    onProgress?.call(0.15, 'Fetching video info...');
    final videoInfo = await fetchVideoInfo(videoId);
    final videoUrl = videoInfo['videoUrl'] as String;

    // Step 3: Download the video file
    onProgress?.call(0.2, 'Downloading video...');
    final outputPath = p.join(outputDir, 'video.mp4');

    await _downloadFile(
      videoUrl,
      outputPath,
      onProgress: onProgress,
    );

    onProgress?.call(1.0, 'Download complete');
    return outputPath;
  }

  /// Downloads a file from [url] to [outputPath] with progress reporting.
  Future<void> _downloadFile(
    String url,
    String outputPath, {
    DownloadProgressCallback? onProgress,
  }) async {
    final client = HttpClient()
      ..userAgent = _mobileUserAgent;

    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', _mobileUserAgent);
      request.headers.set('Referer', 'https://www.douyin.com/');

      final response = await request.close();

      if (response.statusCode != 200 && response.statusCode != 302) {
        await response.drain<void>();

        // If redirect, follow it
        if (response.isRedirect) {
          final location = response.headers.value('location');
          if (location != null) {
            client.close();
            return _downloadFile(location, outputPath, onProgress: onProgress);
          }
        }

        throw DownloadException(
          'Failed to download video (HTTP ${response.statusCode})',
        );
      }

      final contentLength = response.contentLength;
      var receivedBytes = 0;

      final file = File(outputPath);
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (onProgress != null && contentLength > 0) {
          // Map download progress to 0.2 - 1.0 range
          final rawProgress = receivedBytes / contentLength;
          final mappedProgress = 0.2 + rawProgress * 0.8;
          final mb = (receivedBytes / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (contentLength / 1024 / 1024).toStringAsFixed(1);
          onProgress(mappedProgress, 'Downloading: $mb / $totalMb MB');
        }
      }

      await sink.close();

      // Verify file was actually written
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw DownloadException('Downloaded file is empty');
      }
    } finally {
      client.close();
    }
  }

  /// Returns video metadata (title, author, tags) without downloading.
  ///
  /// Useful for displaying info before starting the full pipeline.
  Future<Map<String, dynamic>> getVideoMetadata(String shareUrl) async {
    final url = extractUrl(shareUrl) ?? shareUrl;
    final videoId = await _resolveVideoId(url);
    return fetchVideoInfo(videoId);
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
