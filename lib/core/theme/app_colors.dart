import 'package:flutter/material.dart';

/// 调色板：低饱和度暖灰/米白（浅色）+ 深灰蓝（深色），
/// 强调色用柔和的 sage green / dusty blue。
class AppColors {
  AppColors._();

  // ========= Light =========
  static const Color lightBackground = Color(0xFFF5F2EE); // 暖米白
  static const Color lightSurface = Color(0xFFFDFBF8);    // 卡片底色
  static const Color lightSurfaceAlt = Color(0xFFEEEAE3); // 次级卡片
  static const Color lightAccent = Color(0xFF7C9A7E);     // sage green
  static const Color lightAccentSoft = Color(0xFFB7C9B8);
  static const Color lightTextPrimary = Color(0xFF3A3630);
  static const Color lightTextSecondary = Color(0xFF6E665C);
  static const Color lightDivider = Color(0xFFE3DED5);

  // ========= Dark =========
  static const Color darkBackground = Color(0xFF1A1F2E);  // 深灰蓝
  static const Color darkSurface = Color(0xFF242B3D);
  static const Color darkSurfaceAlt = Color(0xFF2D364B);
  static const Color darkAccent = Color(0xFF7B9EC0);      // dusty blue
  static const Color darkAccentSoft = Color(0xFF4F6E8E);
  static const Color darkTextPrimary = Color(0xFFE8EAF0);
  static const Color darkTextSecondary = Color(0xFFA8AEBE);
  static const Color darkDivider = Color(0xFF374055);

  // ========= 状态色（共用）=========
  static const Color statusInProgress = Color(0xFFD9A86C); // 暖琥珀
  static const Color statusDone = Color(0xFF7C9A7E);       // sage
  static const Color error = Color(0xFFB55C5C);
}
