import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/util/direct_http_client.dart';
import '../models/entry_location.dart';

/// 位置抓取服务。
///
/// 平台分支：
/// - Android / iOS：geolocator 拿坐标 → geocoding 反查得到城市名。
/// - Windows：geolocator 走 Windows.Devices.Geolocation（基于 Wi-Fi / IP，
///   首次会触发系统隐私授权弹窗）拿坐标；geocoding 包不支持 Windows，
///   所以走 BigDataCloud 的免费反查 HTTP（无 key），结果走 HTTPS_PROXY 代理。
/// - 任何平台失败（拒绝授权 / 服务关闭 / 反查失败）→ 抛 [LocationException]，
///   调用方自行决定是否回退到设置页里的"默认天气城市"。
class LocationService {
  /// [httpClient] 默认走 [createDirectHttpClient]——绕开 Clash 直连
  /// BigDataCloud 反查接口；测试可注入 mock 客户端。
  LocationService({http.Client? httpClient})
      : _http = httpClient ?? createDirectHttpClient();

  final http.Client _http;

  /// 反向地理编码 fallback（Windows 用），免 key、HTTPS：
  /// https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=..&longitude=..&localityLanguage=zh
  static const _reverseGeocodeEndpoint =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';

  /// IP 公网反查兜底——Wi-Fi 扫不到 / 系统位置服务关时使用。
  /// 免 key、HTTPS、走直连，精度到城市。1000 次/日的免费配额对单用户够用。
  /// 字段：city、region、country_name、latitude、longitude。
  static const _ipLookupEndpoint = 'https://ipapi.co/json/';

  /// 抓当前位置。整个过程加 [timeout]，超时即抛错。
  Future<EntryLocation> fetchCurrent({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return _withTimeout(_fetchInner(), timeout);
  }

  Future<EntryLocation> _fetchInner() async {
    // 整个流程：先尝试 geolocator（GPS / Wi-Fi 扫描）→ 失败回退 IP 公网反查 →
    // 还失败抛错给上层。IP 兜底主要照顾纯有线 / 无 Wi-Fi 卡 / Wi-Fi 扫不到信号
    // 的台式 + 笔记本场景，精度到城市，对日记打卡足够。
    LocationException? geoError;
    try {
      return await _fetchViaGeolocator();
    } on LocationException catch (e) {
      geoError = e;
    }
    final ip = await _fetchViaIp();
    if (ip != null) return ip;
    // IP 也拿不到 → 把原始 geolocator 错误抛给上层显示。
    throw geoError;
  }

  Future<EntryLocation> _fetchViaGeolocator() async {
    // 1. 检查并请求权限。geolocator 在 Windows 没有"权限"概念，但 API 仍可调；
    //    Windows 端不会进入 deniedForever。
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('系统位置服务已关闭，请在系统设置里打开');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('用户拒绝了位置权限');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('位置权限被永久拒绝，请到系统设置里手动开启');
    }

    // 2. 拿坐标。日记打卡用粗精度足够，不用打到 best/bestForNavigation。
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      // 3. 反向地理编码：Android/iOS 用原生 API，Windows fallback 到 BigDataCloud。
      final placeName = await _reverseGeocode(pos.latitude, pos.longitude);
      return EntryLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        placeName: placeName,
      );
    } catch (e) {
      // 没扫到 Wi-Fi / 设备无 GPS / 反查超时等：包成 LocationException
      // 让 _fetchInner 触发 IP 兜底。
      throw LocationException('未能获取设备位置（$e），尝试按公网 IP 反查');
    }
  }

  /// 按公网 IP 反查城市。直连 ipapi.co；走 [createDirectHttpClient] 保证
  /// 不被 Clash 改变出口 IP，否则反查到的会是代理节点而非真实位置。
  Future<EntryLocation?> _fetchViaIp() async {
    try {
      final resp = await _http
          .get(Uri.parse(_ipLookupEndpoint))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return null;
      // ipapi.co 在限流时返回 200 + {"error": true, "reason": "..."}。
      if (data['error'] == true) return null;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final country = (data['country_name'] as String?)?.trim();

      final nameParts = [city, region, country]
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      final placeName = nameParts.isEmpty ? null : nameParts.first;

      if (lat == null && lng == null && placeName == null) return null;
      return EntryLocation(
        latitude: lat,
        longitude: lng,
        placeName: placeName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        // setLocaleIdentifier 是全局开关，best-effort 调一次让结果走中文。
        // 失败/不支持也不影响 placemarkFromCoordinates。
        await gc.setLocaleIdentifier('zh_CN').catchError((_) {});
        final placemarks = await gc.placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          return _composePlacemark(placemarks.first);
        }
      } catch (_) {
        // 平台原生反查偶尔会拒绝（无网/无服务）→ 回退到 HTTP。
      }
    }
    return _reverseGeocodeViaHttp(lat, lng);
  }

  Future<String?> _reverseGeocodeViaHttp(double lat, double lng) async {
    try {
      final uri = Uri.parse(_reverseGeocodeEndpoint).replace(queryParameters: {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'localityLanguage': 'zh',
      });
      final resp =
          await _http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return null;

      // 字段优先级：city > locality > principalSubdivision > countryName。
      // 拼上区级（localityInfo.administrative[level=4]）给中国地址用，
      // 但同样字段在不同国家含义不同，所以保守只挂 city + 上一级。
      final city = (data['city'] as String?)?.trim();
      final locality = (data['locality'] as String?)?.trim();
      final principal =
          (data['principalSubdivision'] as String?)?.trim();
      final country = (data['countryName'] as String?)?.trim();
      final candidates = [city, locality, principal, country]
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet() // 去重，避免「杭州市·杭州市」
          .toList();
      if (candidates.isEmpty) return null;
      return candidates.first;
    } catch (_) {
      return null;
    }
  }

  String? _composePlacemark(gc.Placemark p) {
    // 中文地址优先 administrativeArea + locality（如 "浙江省 杭州市"），
    // 拿不到就 fallback 到 country。
    final parts = <String>[
      if ((p.locality ?? '').isNotEmpty) p.locality!,
      if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
    ];
    if (parts.isEmpty) {
      final admin = (p.administrativeArea ?? '').trim();
      if (admin.isNotEmpty) parts.add(admin);
    }
    if (parts.isEmpty) {
      final country = (p.country ?? '').trim();
      if (country.isNotEmpty) parts.add(country);
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  Future<T> _withTimeout<T>(Future<T> f, Duration d) {
    return f.timeout(
      d,
      onTimeout: () => throw LocationException('定位超时'),
    );
  }
}

class LocationException implements Exception {
  LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
