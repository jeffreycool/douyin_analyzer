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
      'Chrome/120.0.0.0 Safari/537.36';

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
      headers: {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WeChatException(
        'Failed to fetch article (HTTP ${response.statusCode})',
        details: 'URL: $url',
      );
    }

    final document = html_parser.parse(response.body);

    final title = _extractText(document, '#activity-name')?.trim();
    if (title == null || title.isEmpty) {
      // Check if we hit a verification page
      final bodyText = document.body?.text ?? '';
      if (bodyText.contains('环境异常') || bodyText.contains('去验证')) {
        throw WeChatException(
          'WeChat returned a verification page. '
          'Please try opening the URL in a browser first, then retry.',
          details: 'URL: $url',
        );
      }
      throw WeChatException(
        'Could not extract article title. '
        'The URL may not be a valid WeChat article.',
        details: 'URL: $url',
      );
    }

    final account = _extractText(document, '#js_name')?.trim();
    final author = _extractText(document, '#js_author_name')?.trim();
    final publishTime = _extractText(document, '#publish_time')?.trim();

    final contentElement = document.querySelector('#js_content');
    if (contentElement == null) {
      throw WeChatException(
        'Could not find article content.',
        details: 'URL: $url',
      );
    }

    final content = _extractCleanText(contentElement);
    if (content.trim().isEmpty) {
      throw WeChatException(
        'Article content is empty after extraction.',
        details: 'URL: $url',
      );
    }

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
