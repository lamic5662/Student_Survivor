import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/models/notice_models.dart';

class NoticeCacheService {
  static const String _bcaCacheKey = 'bca_notice_cache_v1';
  static const String _bcaCacheTsKey = 'bca_notice_cache_ts_v1';

  Future<List<BcaNotice>> loadBcaNotices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bcaCacheKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => BcaNotice.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> loadBcaNoticesTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_bcaCacheTsKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> saveBcaNotices(List<BcaNotice> notices) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(notices.map((n) => n.toJson()).toList());
    await prefs.setString(_bcaCacheKey, payload);
    await prefs.setInt(
      _bcaCacheTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
