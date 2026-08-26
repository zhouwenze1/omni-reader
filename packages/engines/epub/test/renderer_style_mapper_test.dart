import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kernel/kernel.dart';

void main() {
  test('maps ReaderStyle to canonical renderer style fields', () {
    const style = ReaderStyle(
      theme: 'night',
      columnCount: 2,
      pageGap: 48,
      fontSize: 22,
      lineHeight: 1.75,
      paddingTop: 12,
      paddingRight: 52,
      paddingBottom: 28,
      paddingLeft: 40,
      textIndentEnabled: false,
      textIndentEm: 1.5,
      textIndentSkipFirstParagraph: true,
    );

    final payload = const RendererStyleMapper().toPayload(style);

    expect(payload, <String, dynamic>{
      'theme': 'night',
      'pageGap': 48,
      'fontSize': 22,
      'lineHeight': 1.75,
      'paddingV': 28,
      'paddingH': 52,
      'textIndentEnabled': false,
      'textIndentEm': 1.5,
      'textIndentSkipFirstParagraph': true,
    });
    expect(payload.containsKey('columnCount'), isFalse);
    expect(payload.containsKey('paddingTop'), isFalse);
    expect(payload.containsKey('paddingRight'), isFalse);
    expect(payload.containsKey('paddingBottom'), isFalse);
    expect(payload.containsKey('paddingLeft'), isFalse);
  });
}
