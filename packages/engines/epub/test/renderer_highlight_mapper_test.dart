import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';

void main() {
  group('RendererHighlightMapper', () {
    test('emits the renderer highlight shape', () {
      const highlight = ReaderHighlight(
        uid: 'hl-1',
        href: 'Text/chapter.xhtml',
        color: '#FFF59D',
        quote: ReaderTextQuote(
          prefix: 'before ',
          exact: 'selected text',
          suffix: ' after',
        ),
        cfi: 'epubcfi(/6/2)',
      );

      final payload = const RendererHighlightMapper().toPayload(highlight);

      expect(payload, <String, dynamic>{
        'uid': 'hl-1',
        'href': 'Text/chapter.xhtml',
        'color': '#FFF59D',
        'anchor': <String, dynamic>{
          'text': <String, dynamic>{
            'prefix': 'before ',
            'exact': 'selected text',
            'suffix': ' after',
          },
          'cfi': 'epubcfi(/6/2)',
        },
      });
    });

    test('extracts a text quote without normalizing it away', () {
      const locator = Locator(
        href: 'Text/chapter.xhtml',
        anchor: <String, dynamic>{
          'text': <String, dynamic>{
            'prefix': 'before ',
            'exact': 'selected',
            'suffix': ' after',
          },
          'xpath': '/html/body/p[1]',
        },
      );

      final quote = const RendererHighlightMapper().quoteFromLocator(locator);

      expect(quote?.exact, 'selected');
      expect(quote?.prefix, 'before ');
      expect(quote?.suffix, ' after');
    });
  });
}
