import 'package:flutter/material.dart';

class AnnotationPalette {
  const AnnotationPalette._();

  static const String yellow = '#FFF59D';
  static const String green = '#A5D6A7';
  static const String blue = '#90CAF9';
  static const String pink = '#F48FB1';
  static const String purple = '#CE93D8';
  static const String defaultColor = yellow;

  static const List<String> colors = <String>[
    yellow,
    green,
    blue,
    pink,
    purple,
  ];

  static Color toColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? const Color(0xFFFFF59D) : Color(parsed);
  }
}
