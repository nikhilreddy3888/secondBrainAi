import 'package:flutter/material.dart';

class AppColors {
  const AppColors(this.isDark);

  final bool isDark;

  Color get bgColor => isDark ? const Color(0xFF151722) : const Color(0xFFF9F5FF);
  Color get surfaceColor => isDark ? const Color(0xFF222533) : Colors.white;
  Color get cardColor => isDark ? const Color(0xFF202330) : const Color(0xFFF3EDFD);
  Color get passwordsColor => isDark ? const Color(0xFF292541) : const Color(0xFFEBE0FA);
  Color get textColor => isDark ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtextColor => isDark ? const Color(0xFFA1A3AE) : const Color(0xFF6B5A8E);
  Color get borderColor => isDark 
      ? Colors.white.withValues(alpha: 0.05) 
      : Colors.black.withValues(alpha: 0.05);

  static AppColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors(isDark);
  }
}
