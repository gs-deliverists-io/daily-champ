import 'package:flutter/material.dart';

/// Temporary compatibility layer for old AppTheme static references
/// This allows old code to compile while we migrate to the new theme system
class AppTheme {
  // Legacy color constants (for backwards compatibility)
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);
  
  // Semantic colors
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textTertiary = Color(0xFFADB5BD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FA);
  static const Color border = Color(0xFFE9ECEF);
  static const Color borderColor = Color(0xFFE9ECEF);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color win = success;
  static const Color loss = error;
  static const Color pending = warning;
  static const Color red = error;
  
  // Spacing
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  
  static const double spacing4 = space4;
  static const double spacing8 = space8;
  static const double spacing12 = space12;
  static const double spacing16 = space16;
  static const double spacing20 = space20;
  static const double spacing24 = space24;
  static const double spacing32 = space32;
  static const double spacing40 = space40;
  static const double spacing48 = space48;
  
  // Radius
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
  static const double radiusFull = 999.0;
  static const double radiusSmall = radius8;
  static const double radiusMedium = radius12;
  static const double radiusLarge = radius16;
  
  // Typography stubs (these should use Theme.of(context) in real code)
  static const TextStyle displayLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
  static const TextStyle displayMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w600);
  static const TextStyle headlineLarge = TextStyle(fontSize: 24, fontWeight: FontWeight.w600);
  static const TextStyle headlineMedium = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const TextStyle titleLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
  static const TextStyle bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
  static const TextStyle labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
}
