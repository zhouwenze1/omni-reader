import 'dart:io';

import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

void main() {
  group('BookPositionIndex', () {
    test('maps chapter progression to total progression', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'book_position_index_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final storage = BookStorageService(
        booksRootPath: p.join(tempRoot.path, 'books'),
      );
      await storage.saveArtifactFileMap(
        'book_1',
        <String, Map<String, Object?>>{
          'positions.json': <String, Object?>{
            'total': 4,
            'positions': <Map<String, Object?>>[
              <String, Object?>{
                'href': 'Text/ch1.xhtml',
                'locations': <String, Object?>{
                  'progression': 0.0,
                  'totalProgression': 0.0,
                },
              },
              <String, Object?>{
                'href': 'Text/ch1.xhtml',
                'locations': <String, Object?>{
                  'progression': 1.0,
                  'totalProgression': 0.3,
                },
              },
              <String, Object?>{
                'href': 'Text/ch2.xhtml',
                'locations': <String, Object?>{
                  'progression': 0.0,
                  'totalProgression': 0.3,
                },
              },
              <String, Object?>{
                'href': 'Text/ch2.xhtml',
                'locations': <String, Object?>{
                  'progression': 1.0,
                  'totalProgression': 1.0,
                },
              },
            ],
          },
        },
      );

      final index = await BookPositionIndex.load(
        storageService: storage,
        bookUuid: 'book_1',
      );

      expect(index, isNotNull);
      expect(
        index!.resolveTotalProgressionForLocator(
          const Locator(
            href: 'Text/ch2.xhtml',
            locations: <String, dynamic>{'progression': 0.5},
          ),
        ),
        closeTo(0.65, 0.0001),
      );
    });

    test('maps total progression back to chapter locator', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'book_position_index_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final storage = BookStorageService(
        booksRootPath: p.join(tempRoot.path, 'books'),
      );
      await storage.saveArtifactFileMap(
        'book_2',
        <String, Map<String, Object?>>{
          'positions.json': <String, Object?>{
            'total': 3,
            'positions': <Map<String, Object?>>[
              <String, Object?>{
                'href': 'Text/ch1.xhtml',
                'locations': <String, Object?>{
                  'progression': 0.0,
                  'totalProgression': 0.0,
                },
              },
              <String, Object?>{
                'href': 'Text/ch1.xhtml',
                'locations': <String, Object?>{
                  'progression': 1.0,
                  'totalProgression': 0.5,
                },
              },
              <String, Object?>{
                'href': 'Text/ch2.xhtml',
                'locations': <String, Object?>{
                  'progression': 1.0,
                  'totalProgression': 1.0,
                },
              },
            ],
          },
        },
      );

      final index = await BookPositionIndex.load(
        storageService: storage,
        bookUuid: 'book_2',
      );

      expect(index, isNotNull);
      final locator = index!.resolveLocatorForTotalProgression(0.25);
      expect(locator, isNotNull);
      expect(locator!.href, 'Text/ch1.xhtml');
      expect(
        (locator.locations?['progression'] as num?)?.toDouble(),
        closeTo(0.5, 0.0001),
      );
    });
  });
}
