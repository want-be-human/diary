import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/util/direct_http_client.dart';
import '../models/weather_snapshot.dart';

/// 当前天气服务（基于 uapis.cn）。
///
/// 端点：`GET https://uapis.cn/api/v1/misc/weather`，无需 API key。
/// 三种查询方式（优先级：adcode > city > IP 自动定位）：
/// - `city=北京` / `city=Tokyo`：按城市名查（中英文都行，覆盖 7000+ 城市）
/// - 不传任何参数：服务端按客户端 IP 自动定位
///
/// 注意：uapis.cn **不接受** `lat`/`lng` 参数。所以坐标查天气的旧用法已废弃；
/// 新流程是 LocationService 反查得到 `placeName` 后，直接传 `city` 参数。
///
/// 文档：https://uapis.cn/docs/api-reference/get-misc-weather
class WeatherService {
  /// [httpClient] 默认走 [createDirectHttpClient]——uapis.cn 是国内服务，
  /// 走 Clash 反而绕远（出口到海外节点会失败/超时）。测试可注入 mock。
  WeatherService({http.Client? httpClient})
      : _http = httpClient ?? createDirectHttpClient();

  static const _endpoint = 'https://uapis.cn/api/v1/misc/weather';

  final http.Client _http;

  /// 按城市名抓。[cityName] 留空 → 走 [fetchByIp]。
  Future<WeatherSnapshot?> fetchByCityName(String cityName) {
    final trimmed = cityName.trim();
    if (trimmed.isEmpty) return fetchByIp();
    return _fetch(city: trimmed);
  }

  /// 不传任何参数，让 uapis.cn 按客户端公网 IP 自动定位查询。
  /// 返回的 [WeatherSnapshot.cityName] 携带服务端解析出的真实城市，
  /// 编辑器可借此把 location.placeName 也顺手回填，省一次反查。
  Future<WeatherSnapshot?> fetchByIp() => _fetch();

  Future<WeatherSnapshot?> _fetch({String? city}) async {
    try {
      final qp = <String, String>{
        'lang': 'zh',
        if (city != null && city.isNotEmpty) 'city': city,
      };
      final uri = Uri.parse(_endpoint).replace(queryParameters: qp);
      final resp =
          await _http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return null;
      // uapis.cn 错误响应是 {code, message}，没有 temperature。
      final temp = (data['temperature'] as num?)?.toDouble();
      if (temp == null) return null;

      final weatherText = (data['weather'] as String?) ?? '';
      // 城市名优先用 city；district（区县）作为补充——按 IP 定位时
      // city 是"杭州"、district 是"西湖区"，拼一起更精确。
      final cityName = (data['city'] as String?)?.trim();
      final district = (data['district'] as String?)?.trim();
      final composed = <String>[
        if (cityName != null && cityName.isNotEmpty) cityName,
        if (district != null && district.isNotEmpty) district,
      ].join(' ');

      return WeatherSnapshot(
        condition: _mapWeatherText(weatherText),
        tempCelsius: temp,
        cityName: composed.isEmpty ? null : composed,
      );
    } catch (_) {
      return null;
    }
  }

  /// 把 uapis 的 `weather` 文本（非固定枚举）匹配到本项目的 [WeatherCondition]。
  /// 顺序很重要——"雨夹雪" 含"雨"和"雪"，先匹配"雨"归为 rainy（湿天气，
  /// 用户体感更接近雨）。常见值参考文档：晴/多云/阴/小雨/中雨/大雨/雷阵雨/
  /// 小雪/中雪/大雪/雨夹雪/雾/霾/沙尘。
  WeatherCondition _mapWeatherText(String t) {
    if (t.isEmpty) return WeatherCondition.unknown;
    if (t.contains('晴')) return WeatherCondition.sunny;
    if (t.contains('雨')) return WeatherCondition.rainy;
    if (t.contains('雪')) return WeatherCondition.snowy;
    if (t.contains('多云') || t.contains('阴')) {
      return WeatherCondition.cloudy;
    }
    if (t.contains('雾') ||
        t.contains('霾') ||
        t.contains('沙尘') ||
        t.contains('浮尘') ||
        t.contains('扬沙')) {
      return WeatherCondition.fog;
    }
    if (t.contains('风')) return WeatherCondition.windy;
    return WeatherCondition.unknown;
  }
}

final weatherServiceProvider =
    Provider<WeatherService>((ref) => WeatherService());
