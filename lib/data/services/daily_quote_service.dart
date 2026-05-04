import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 每日一言数据源：UAPI `https://uapis.cn/api/v1/saying`。
///
/// 缓存策略：按日期键存到 SharedPreferences，同一天命中缓存不再发请求。
/// 一天换一句新的，符合"每日一言"的语义。
/// 失败时返回 null，由 UI 决定降级（隐藏/显示空骨架）。
class DailyQuoteService {
  DailyQuoteService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _endpoint = 'https://uapis.cn/api/v1/saying';
  static const _kPrefix = 'daily_quote.';

  final http.Client _http;

  Future<String?> getToday() async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_kPrefix$today');
    if (cached != null && cached.isNotEmpty) return cached;

    // 顺手清掉昨日及更早的旧 key，避免 prefs 慢慢膨胀。
    final stale = prefs
        .getKeys()
        .where((k) => k.startsWith(_kPrefix) && k != '$_kPrefix$today');
    for (final k in stale) {
      await prefs.remove(k);
    }

    try {
      final resp = await _http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body);
      final text = (data is Map ? data['text'] : null) as String?;
      if (text == null || text.isEmpty) return null;
      await prefs.setString('$_kPrefix$today', text);
      return text;
    } catch (_) {
      return null;
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

final dailyQuoteServiceProvider =
    Provider<DailyQuoteService>((ref) => DailyQuoteService());

/// FutureProvider：当天首次访问会发请求；之后命中缓存。
/// invalidate 此 provider 可强制重新请求（比如下拉刷新）。
final dailyQuoteProvider = FutureProvider<String?>((ref) async {
  return ref.read(dailyQuoteServiceProvider).getToday();
});
