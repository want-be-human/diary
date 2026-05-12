import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用偏好持久化（除主题以外的）。
///
/// 当前只存"默认天气城市"——位置权限关闭 / 桌面端不愿暴露坐标时，编辑器
/// 会拿这里的城市去 forward-geocode + 抓天气。后续若新增"默认导出格式"
/// "默认图片处理方式"等设置，统一往这里塞。
class SettingsService {
  static const _kDefaultCity = 'settings.default_city';

  Future<String> getDefaultCity() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kDefaultCity) ?? '').trim();
  }

  Future<void> setDefaultCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_kDefaultCity);
    } else {
      await prefs.setString(_kDefaultCity, trimmed);
    }
  }
}

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

/// 默认天气城市 reactive 状态：编辑器里读、设置页里写。
class DefaultCityController extends AsyncNotifier<String> {
  @override
  Future<String> build() => ref.read(settingsServiceProvider).getDefaultCity();

  Future<void> set(String value) async {
    await ref.read(settingsServiceProvider).setDefaultCity(value);
    state = AsyncValue.data(value.trim());
  }
}

final defaultCityProvider =
    AsyncNotifierProvider<DefaultCityController, String>(
  DefaultCityController.new,
);
