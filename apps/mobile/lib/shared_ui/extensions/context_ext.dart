import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textStyles => Theme.of(this).textTheme;

  ScaffoldMessengerState get messenger => ScaffoldMessenger.of(this);
}
