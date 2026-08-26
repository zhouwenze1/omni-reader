import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';

void main() {
  group('Renderer API models', () {
    test('exposes the canonical renderer command names', () {
      expect(
        RendererCommand.values.map((command) => command.wireName),
        <String>[
          'init',
          'configure',
          'open',
          'navigate',
          'clearSelection',
          'reset',
          'getSelectionAnchor',
          'applyHighlight',
          'applyHighlights',
          'removeHighlight',
          'updateHighlight',
        ],
      );
      expect(rendererCommandFromWireName('setStyle'), isNull);
      expect(rendererCommandFromWireName('setCustomCss'), isNull);
    });

    test('serializes strict navigation payloads', () {
      expect(const RendererNavigatePayload.next().toJson(), <String, dynamic>{
        'kind': 'next',
      });
      expect(const RendererNavigatePayload.prev().toJson(), <String, dynamic>{
        'kind': 'prev',
      });
      expect(
        const RendererNavigatePayload.progression(0.375).toJson(),
        <String, dynamic>{'kind': 'progression', 'value': 0.375},
      );
      expect(
        const RendererNavigatePayload.anchor('epubcfi(/6/2)').toJson(),
        <String, dynamic>{'kind': 'anchor', 'value': 'epubcfi(/6/2)'},
      );
    });

    test('maps adaptive paging to a concrete renderer mode', () {
      expect(
        ReaderLayoutMode.normalizeRendererMode(ReaderLayoutMode.pagedAuto),
        ReaderLayoutMode.pagedSingle,
      );
      expect(
        ReaderLayoutMode.resolveAdaptive(
          ReaderLayoutMode.pagedAuto,
          shortestSide: 720,
        ),
        ReaderLayoutMode.pagedSpread,
      );
    });
  });
}
