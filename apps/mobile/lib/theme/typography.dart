import 'package:flutter/material.dart';

TextTheme buildMobileTextTheme(ColorScheme colorScheme) {
  final base = Typography.material2021().black;
  return base.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );
}
