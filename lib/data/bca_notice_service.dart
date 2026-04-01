import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:student_survivor/models/notice_models.dart';

class BcaNoticeService {
  static const String _baseUrl = 'https://fohss.tu.edu.np';
  static const String _noticesPath = '/notices';
  final http.Client _client;

  BcaNoticeService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<BcaNotice>> fetchNotices({int limit = 20}) async {
    final response = await _client.get(Uri.parse('$_baseUrl$_noticesPath'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load TU notices.');
    }

    final document = html_parser.parse(response.body);
    final anchorNodes = document.querySelectorAll('a');
    final candidates = <_NoticeMeta>[];

    for (final anchor in anchorNodes) {
      final title = anchor.text.trim();
      if (title.isEmpty) continue;
      final href = anchor.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      final uri = Uri.tryParse(href);
      final path = uri?.path ?? href;
      if (!RegExp(r'/notices/\d+$').hasMatch(path)) {
        continue;
      }
      final fullUrl = _resolveUrl('$_baseUrl$path', href);
      final date = _extractDate(anchor.parent?.text ?? '');
      candidates.add(
        _NoticeMeta(
          title: title,
          url: fullUrl,
          date: date,
        ),
      );
    }

    final seen = <String>{};
    final filtered = <_NoticeMeta>[];
    for (final item in candidates) {
      if (seen.contains(item.url)) continue;
      seen.add(item.url);
      if (!_isBcaNotice(item.title)) continue;
      filtered.add(item);
    }

    final sliced = filtered.take(limit).toList();
    final notices = await Future.wait(
      sliced.map(
        (item) async {
          final attachmentUrl = await _fetchAttachmentUrl(item.url);
          return BcaNotice(
            title: item.title,
            url: item.url,
            publishedAt: item.date,
            attachmentUrl: attachmentUrl,
          );
        },
      ),
    );
    return notices;
  }

  bool _isBcaNotice(String title) {
    final lower = title.toLowerCase();
    return lower.contains('bca') ||
        lower.contains('b.c.a') ||
        lower.contains('bachelor in computer application') ||
        lower.contains('computer application');
  }

  DateTime? _extractDate(String text) {
    final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text);
    if (match == null) {
      return null;
    }
    return DateTime.tryParse(match.group(0)!);
  }

  Future<String?> _fetchAttachmentUrl(String noticeUrl) async {
    try {
      final response = await _client.get(Uri.parse(noticeUrl));
      if (response.statusCode != 200) return null;
      final document = html_parser.parse(response.body);
      final anchors = document.querySelectorAll('a');
      for (final anchor in anchors) {
        final href = anchor.attributes['href']?.trim() ?? '';
        if (href.isEmpty) continue;
        if (_looksLikeFile(href)) {
          return _resolveUrl(noticeUrl, href);
        }
      }
    } catch (_) {}
    return null;
  }

  bool _looksLikeFile(String href) {
    final lower = href.toLowerCase();
    if (lower.contains('portal.tu.edu.np')) return true;
    return RegExp(r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx)$').hasMatch(lower);
  }

  String _resolveUrl(String base, String href) {
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) {
      return uri.toString();
    }
    return Uri.parse(base).resolve(href).toString();
  }
}

class _NoticeMeta {
  final String title;
  final String url;
  final DateTime? date;

  const _NoticeMeta({
    required this.title,
    required this.url,
    required this.date,
  });
}
