import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';

void main() {
  group('RendererLocatorMapper', () {
    test('emits only canonical locator fields', () {
      const locator = Locator(
        href: 'Text/chapter.xhtml',
        url: 'http://127.0.0.1:1234/Text/chapter.xhtml',
        cfi: 'epubcfi(/6/2)',
        locations: <String, dynamic>{
          'position': '7',
          'progression': '0.25',
          'totalProgression': 0.4,
          'cfi': 'legacy-cfi',
        },
        anchor: <String, dynamic>{
          'uid': 'p-7',
          'offset': '3',
          'offsetEnd': 11,
          'xpath': '/html/body/p[7]',
          'rect': <String, dynamic>{'left': 1},
        },
        text: 'A selected sentence',
        extras: <String, dynamic>{'internal': true},
      );

      final payload = const RendererLocatorMapper().toPayload(locator);

      expect(payload, <String, dynamic>{
        'href': 'Text/chapter.xhtml',
        'cfi': 'epubcfi(/6/2)',
        'locations': <String, dynamic>{
          'position': 7,
          'progression': 0.25,
          'totalProgression': 0.4,
        },
        'anchor': <String, dynamic>{'uid': 'p-7', 'offset': 3, 'offsetEnd': 11},
        'text': <String, dynamic>{'highlight': 'A selected sentence'},
      });
      expect(payload.containsKey('url'), isFalse);
      expect(payload.containsKey('extras'), isFalse);
      expect((payload['locations'] as Map).containsKey('cfi'), isFalse);
      expect((payload['anchor'] as Map).containsKey('xpath'), isFalse);
      expect((payload['anchor'] as Map).containsKey('rect'), isFalse);
    });

    test('keeps legacy locator reads while producing canonical output', () {
      final payload = const RendererLocatorMapper().normalizePayload(
        <String, dynamic>{
          'url': 'book://book-1/Text/chapter.xhtml',
          'text': <String, dynamic>{'highlight': 'legacy text'},
          'anchor': <String, dynamic>{'uid': 'p-1', 'offset': '2'},
        },
      );

      expect(payload, <String, dynamic>{
        'href': 'Text/chapter.xhtml',
        'anchor': <String, dynamic>{'uid': 'p-1', 'offset': 2},
        'text': 'legacy text',
      });

      final canonical = const RendererLocatorMapper().toPayload(
        const Locator(href: 'Text/chapter.xhtml', text: 'legacy text'),
      );
      expect(canonical['text'], <String, dynamic>{'highlight': 'legacy text'});
    });
  });
}
