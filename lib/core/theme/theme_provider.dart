import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式持久化键。
const String _kThemeModeKey = 'app.theme_mode';

/// 主题模式 Provider。
/// 默认 [ThemeMode.system]（跟随系统），用户切换后写入 SharedPreferences。
final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
    state = _decode(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _encode(mode));
  }

  /// 在 light <-> dark 间切换；当前为 system 时切到与系统相反的固定模式。
  Future<void> toggle(BuildContext context) async {
    switch (state) {
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setMode(ThemeMode.light);
        break;
      case ThemeMode.system:
        final isDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
        break;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
