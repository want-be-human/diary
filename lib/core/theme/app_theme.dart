import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// 浅色 / 深色主题。
/// 风格：简约、柔和、淡雅；大量留白；圆角卡片；无重色块。
/// UI 字体使用系统无衬线，正文（详情页/编辑器）回退到 Georgia/serif。
class AppTheme {
  AppTheme._();

  static const double _radiusLarge = 16;
  static const double _radiusMedium = 12;
  static const double _radiusSmall = 8;

  static const List<String> _serifFallback = ['Georgia', 'serif'];

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surfaceAlt: AppColors.lightSurfaceAlt,
        accent: AppColors.lightAccent,
        accentSoft: AppColors.lightAccentSoft,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        divider: AppColors.lightDivider,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        surfaceAlt: AppColors.darkSurfaceAlt,
        accent: AppColors.darkAccent,
        accentSoft: AppColors.darkAccentSoft,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        divider: AppColors.darkDivider,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color accent,
    required Color accentSoft,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.light
          ? AppColors.lightSurface
          : AppColors.darkBackground,
      secondary: accentSoft,
      onSecondary: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceAlt,
      error: AppColors.error,
      onError: Colors.white,
      outline: divider,
    );

    final baseText = TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineMedium:
          TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      // 正文使用衬线字体，营造日记感
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 16,
        height: 1.6,
        fontFamilyFallback: _serifFallback,
      ),
      bodyMedium: TextStyle(
        color: textPrimary,
        fontSize: 14.5,
        height: 1.55,
        fontFamilyFallback: _serifFallback,
      ),
      bodySmall: TextStyle(
        color: textSecondary,
        fontSize: 13,
        height: 1.5,
      ),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: textSecondary),
      labelSmall: TextStyle(color: textSecondary, fontSize: 11),
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
          side: BorderSide(color: divider, width: 0.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMedium),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: BorderSide(color: accent, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: accentSoft,
        side: BorderSide(color: divider),
        labelStyle: TextStyle(color: textPrimary),
        secondaryLabelStyle: TextStyle(color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.6,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
