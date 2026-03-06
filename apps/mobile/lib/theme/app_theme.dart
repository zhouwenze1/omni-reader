import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'color_schemes.dart';
import 'typography.dart';

class MobileAppTheme {
  const MobileAppTheme._();

  static ThemeData light() {
    return _theme(mobileLightColorScheme);
  }

  static ThemeData dark() {
    return _theme(mobileDarkColorScheme);
  }

  static ThemeMode modeFromSettings(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  static ThemeData _theme(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: buildMobileTextTheme(colorScheme),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
