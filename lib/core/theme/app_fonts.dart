/// 全局字体常量。
///
/// 已打包到 `assets/fonts/`：
/// - Fraunces Regular + Italic（英文衬线）
/// - FrauncesItalic（同 Italic，但当作 normal-style 注册，给"英文 italic +
///   中文 regular"混排用，避免 Flutter 对 fallback 的中文字体做 synthetic
///   italic）
/// - NotoSerifSC Regular（中文衬线）
///
/// fallback 列表里继续保留系统字体名，给没装这些字体的极端环境兜底。
class AppFonts {
  AppFonts._();

  // === 衬线（混排，Regular）===
  static const String serifPrimary = 'Fraunces';
  static const List<String> serifFallback = [
    'NotoSerifSC',
    'Songti SC',
    'STSong',
    'SimSun',
    'Georgia',
    'serif',
  ];

  // === 衬线 + 永远 italic 英文 + 正体中文 ===
  /// 用于"每日一言"等优雅引文：英文走斜体 Fraunces，中文落到 NotoSerifSC 正体。
  static const String serifItalicEnPrimary = 'FrauncesItalic';
  static const List<String> serifItalicEnFallback = [
    'NotoSerifSC',
    'Songti SC',
    'STSong',
    'SimSun',
    'Georgia',
    'serif',
  ];

  // === 中文衬线（Regular）===
  static const String serifZhPrimary = 'NotoSerifSC';
  static const List<String> serifZhFallback = [
    'Songti SC',
    'STSong',
    'SimSun',
    'Fraunces',
    'Georgia',
    'serif',
  ];

  // === 无衬线（系统字体兜底，未打包）===
  static const List<String> sansFallback = [
    'Noto Sans SC',
    'PingFang SC',
    'Microsoft YaHei',
    '-apple-system',
    'sans-serif',
  ];

  // === 等宽（系统字体兜底，未打包）===
  static const List<String> monoFallback = [
    'IBM Plex Mono',
    'SF Mono',
    'Menlo',
    'Consolas',
    'monospace',
  ];
}
