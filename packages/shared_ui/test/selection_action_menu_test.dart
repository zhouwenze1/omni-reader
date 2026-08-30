import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  test('places the menu above the selection when there is room', () {
    final offset = computeMenuOffset(
      selectionRect: const Rect.fromLTWH(100, 200, 40, 20),
      viewport: const Size(400, 800),
      menuSize: const Size(220, 52),
    );

    expect(offset, const Offset(10, 140));
  });

  test('uses the lower side and clamps horizontal overflow', () {
    final offset = computeMenuOffset(
      selectionRect: const Rect.fromLTWH(380, 4, 10, 20),
      viewport: const Size(400, 300),
      menuSize: const Size(220, 52),
    );

    expect(offset, const Offset(172, 32));
  });
}
