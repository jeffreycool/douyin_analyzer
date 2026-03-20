import 'dart:convert';

import 'package:get/get.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;

/// Data class holding parsed WeChat article content.
class WeChatArticle {
  final String title;
  final String? account;
  final String? author;
  final String? publishTime;
  final String content;

  WeChatArticle({
    required this.title,
    this.account,
    this.author,
    this.publishTime,
    required this.content,
  });
}

/// Service for fetching and parsing WeChat public account articles.
class WeChatService extends GetxService {
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  static const _defaultHeaders = {
    'User-Agent': _userAgent,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://mp.weixin.qq.com/',
    'sec-ch-ua':
        '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"macOS"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Cache-Control': 'max-age=0',
  };

  /// Returns true if the URL points to a WeChat article.
  static bool isWeChatUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host == 'mp.weixin.qq.com' ||
        uri.host.endsWith('.weixin.qq.com');
  }

  /// Fetches and parses a WeChat article from the given URL.
  Future<WeChatArticle> fetchArticle(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: _defaultHeaders,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WeChatException(
        'Failed to fetch article (HTTP ${response.statusCode})',
        details: 'URL: $url',
      );
    }

    // Always decode as UTF-8 to handle Chinese content correctly,
    // regardless of what the Content-Type header says.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);

    // Check for verification page in raw HTML before parsing.
    // The verification text may be inside <script> tags or JS strings,
    // so checking raw HTML is more reliable than parsed DOM text.
    if (body.contains('环境异常') ||
        body.contains('verify.html') ||
        body.contains('去验证')) {
      throw WeChatException(
        'WeChat 返回了验证页面，请先在浏览器中打开该链接完成验证后重试。',
        details: 'URL: $url',
      );
    }

    final document = html_parser.parse(body);

    // Extract title: try DOM element first, fall back to og:title meta tag.
    // Some WeChat articles (short posts, video posts) don't have #activity-name
    // in the server-rendered HTML — the element is populated by JavaScript.
    final title = _extractText(document, '#activity-name')?.trim() ??
        _extractMeta(document, 'og:title');
    if (title == null || title.isEmpty) {
      throw WeChatException(
        'Could not extract article title. '
        'The URL may not be a valid WeChat article.',
        details: 'URL: $url',
      );
    }

    final account = _extractText(document, '#js_name')?.trim() ??
        _extractJsVar(body, 'nickname');
    final author = _extractText(document, '#js_author_name')?.trim();
    final publishTime = _extractText(document, '#publish_time')?.trim();

    // Extract content: try #js_content DOM element first, fall back to
    // og:description meta tag for articles without server-rendered content.
    String? content;
    final contentElement = document.querySelector('#js_content');
    if (contentElement != null) {
      content = _extractCleanText(contentElement);
    }
    if (content == null || content.trim().isEmpty) {
      content = _extractMeta(document, 'og:description');
    }
    if (content == null || content.trim().isEmpty) {
      throw WeChatException(
        'Article content is empty after extraction.',
        details: 'URL: $url',
      );
    }

    // Clean up escaped characters from meta tag content
    content = content
        .replaceAll(r'\x0a', '\n')
        .replaceAll(r'\x26lt;', '<')
        .replaceAll(r'\x26gt;', '>')
        .replaceAll(r'\x26amp;', '&')
        .replaceAll(r'\x26quot;', '"')
        .replaceAll(RegExp(r'<[^>]+>'), '') // strip any HTML tags
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return WeChatArticle(
      title: title,
      account: account,
      author: author,
      publishTime: publishTime,
      content: content,
    );
  }

  String? _extractText(dom.Document document, String selector) {
    return document.querySelector(selector)?.text;
  }

  /// Extracts content from an OpenGraph or Twitter meta tag.
  String? _extractMeta(dom.Document document, String property) {
    // Try property="og:xxx" (OpenGraph)
    final og = document.querySelector('meta[property="$property"]');
    if (og != null) return og.attributes['content']?.trim();
    // Try name="xxx" (Twitter cards, etc.)
    final meta = document.querySelector('meta[name="$property"]');
    return meta?.attributes['content']?.trim();
  }

  /// Extracts a JavaScript variable value from raw HTML.
  /// Handles both single-quoted and double-quoted values.
  String? _extractJsVar(String html, String varName) {
    final match =
        RegExp("var\\s+$varName\\s*=\\s*[\"']([^\"']*)[\"']").firstMatch(html);
    return match?.group(1)?.trim();
  }

  /// Converts an HTML element tree to clean, readable plain text.
  String _extractCleanText(dom.Element element) {
    final buffer = StringBuffer();
    _walkNodes(element, buffer);
    var text = buffer.toString();
    text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    return text.trim();
  }

  void _walkNodes(dom.Node node, StringBuffer buffer) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is dom.Element) {
      // Skip script/style tags
      final tag = node.localName?.toLowerCase();
      if (tag == 'script' || tag == 'style') return;

      const blockTags = {
        'p', 'div', 'section', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'blockquote', 'ul', 'ol',
      };
      const breakTags = {'br', 'hr'};

      if (blockTags.contains(tag)) {
        buffer.write('\n\n');
      } else if (breakTags.contains(tag)) {
        buffer.write('\n');
      } else if (tag == 'li') {
        buffer.write('\n- ');
      }

      for (final child in node.nodes) {
        _walkNodes(child, buffer);
      }

      if (blockTags.contains(tag)) {
        buffer.write('\n\n');
      }
    }
  }
}

/// Exception thrown when WeChat article fetching or parsing fails.
class WeChatException implements Exception {
  final String message;
  final String? details;

  WeChatException(this.message, {this.details});

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return 'WeChatException: $message\nDetails: $details';
    }
    return 'WeChatException: $message';
  }
}
