import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 每日一言数据源：hitokoto `https://v1.hitokoto.cn/`。
///
/// 不传 `c` 参数 → 后端随机选择句子类型
/// （动漫/漫画/游戏/文学/原创/网络/其他/影视/诗词/网易云/哲学/抖机灵）。
/// 响应 JSON 字段：`hitokoto`（句子）+ `from` / `from_who`（出处）。
///
/// 缓存策略：按日期键存到 SharedPreferences，同一天命中缓存不再发请求。
/// 一天换一句新的，符合"每日一言"的语义。
/// `force = true` 时跳过缓存读，重新请求，用于点击刷新。
class DailyQuoteService {
  DailyQuoteService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _endpoint = 'https://v1.hitokoto.cn/';
  static const _kPrefix = 'daily_quote.';

  final http.Client _http;

  Future<String?> getToday({bool force = false}) async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final cached = prefs.getString('$_kPrefix$today');
      if (cached != null && cached.isNotEmpty) return cached;
    }

    // 顺手清掉昨日及更早的旧 key，避免 prefs 慢慢膨胀。
    final stale = prefs
        .getKeys()
        .where((k) => k.startsWith(_kPrefix) && k != '$_kPrefix$today')
        .toList();
    for (final k in stale) {
      await prefs.remove(k);
    }

    try {
      final resp = await _http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return null;
      final text = data['hitokoto'] as String?;
      if (text == null || text.isEmpty) return null;
      // 拼上出处：优先 `from_who`（人物），否则 `from`（作品/来源）。
      final fromWho = (data['from_who'] as String?)?.trim();
      final from = (data['from'] as String?)?.trim();
      final attribution = [fromWho, from]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join('·');
      final composed =
          attribution.isEmpty ? text : '$text\n—— $attribution';
      await prefs.setString('$_kPrefix$today', composed);
      return composed;
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

/// 每日一言 controller：build 时从缓存/网络拉取，refresh() 强制重拉。
class DailyQuoteController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return ref.read(dailyQuoteServiceProvider).getToday();
  }

  /// 用户点击刷新：跳过缓存，重新请求。
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(dailyQuoteServiceProvider).getToday(force: true),
    );
  }
}

final dailyQuoteProvider =
    AsyncNotifierProvider<DailyQuoteController, String?>(
  DailyQuoteController.new,
);
