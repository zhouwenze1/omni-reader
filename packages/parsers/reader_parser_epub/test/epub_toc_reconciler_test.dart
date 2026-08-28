import 'dart:convert';
import 'dart:typed_data';

import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:reader_parser_epub/src/parser/epub_toc_reconciler.dart';
import 'package:test/test.dart';

void main() {
  group('EpubTocReconciler', () {
    test(
      'adds orphaned spine items under the nearest section parent',
      () async {
        const reconciler = EpubTocReconciler();
        final source = _MemoryResourceSource(
          files: <String, String>{
            'OEBPS/Text/part1.xhtml':
                '<html><body><h1>Part 1</h1></body></html>',
            'OEBPS/Text/ch1.xhtml':
                '<html><body><h1>Chapter 1</h1></body></html>',
            'OEBPS/Text/ch2.xhtml':
                '<html><body><h1>Chapter 2</h1></body></html>',
            'OEBPS/Text/part2.xhtml':
                '<html><body><h1>Part 2</h1></body></html>',
            'OEBPS/Text/ch3.xhtml':
                '<html><body><h1>Chapter 3</h1></body></html>',
          },
        );

        final reconciled = await reconciler.reconcile(
          toc: const <BookTocItem>[
            BookTocItem(
              id: 'part_1',
              title: 'Part 1',
              href: 'OEBPS/Text/part1.xhtml',
              order: 0,
            ),
            BookTocItem(
              id: 'part_2',
              title: 'Part 2',
              href: 'OEBPS/Text/part2.xhtml',
              order: 1,
            ),
          ],
          readingOrder: const <BookAssetItem>[
            BookAssetItem(
              id: 'part_1',
              href: 'Text/part1.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'ch_1',
              href: 'Text/ch1.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'ch_2',
              href: 'Text/ch2.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'part_2',
              href: 'Text/part2.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'ch_3',
              href: 'Text/ch3.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
          ],
          resourceSource: source,
          contentRoot: 'OEBPS',
        );

        expect(reconciled.map((item) => item.title), <String>[
          'Part 1',
          'Chapter 1',
          'Chapter 2',
          'Part 2',
          'Chapter 3',
        ]);
        expect(reconciled.map((item) => item.level), <int>[0, 1, 1, 0, 1]);
        expect(reconciled.map((item) => item.parentId), <String?>[
          null,
          'part_1',
          'part_1',
          null,
          'part_2',
        ]);
      },
    );

    test(
      'keeps missing top-level chapters as siblings when no section parent exists',
      () async {
        const reconciler = EpubTocReconciler();
        final source = _MemoryResourceSource(
          files: <String, String>{
            'OEBPS/Text/ch1.xhtml':
                '<html><body><h1>Chapter 1</h1></body></html>',
            'OEBPS/Text/ch2.xhtml':
                '<html><body><h1>Chapter 2</h1></body></html>',
            'OEBPS/Text/ch3.xhtml':
                '<html><body><h1>Chapter 3</h1></body></html>',
            'OEBPS/Text/ch4.xhtml':
                '<html><body><h1>Chapter 4</h1></body></html>',
          },
        );

        final reconciled = await reconciler.reconcile(
          toc: const <BookTocItem>[
            BookTocItem(
              id: 'chapter_1',
              title: 'Chapter 1',
              href: 'OEBPS/Text/ch1.xhtml',
              order: 0,
            ),
            BookTocItem(
              id: 'chapter_4',
              title: 'Chapter 4',
              href: 'OEBPS/Text/ch4.xhtml',
              order: 1,
            ),
          ],
          readingOrder: const <BookAssetItem>[
            BookAssetItem(
              id: 'chapter_1',
              href: 'Text/ch1.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'chapter_2',
              href: 'Text/ch2.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'chapter_3',
              href: 'Text/ch3.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
            BookAssetItem(
              id: 'chapter_4',
              href: 'Text/ch4.xhtml',
              mediaType: 'application/xhtml+xml',
            ),
          ],
          resourceSource: source,
          contentRoot: 'OEBPS',
        );

        expect(reconciled.map((item) => item.title), <String>[
          'Chapter 1',
          'Chapter 2',
          'Chapter 3',
          'Chapter 4',
        ]);
        expect(reconciled.every((item) => item.level == 0), isTrue);
        expect(reconciled.every((item) => item.parentId == null), isTrue);
      },
    );

    test('builds fallback toc from spine when navigation is missing', () async {
      const reconciler = EpubTocReconciler();
      final source = _MemoryResourceSource(
        files: <String, String>{
          'OEBPS/Text/ch1.xhtml':
              '<html><head><title>Opening</title></head><body><p>Intro</p></body></html>',
          'OEBPS/Text/ch2.xhtml': '<html><body><h1>Middle</h1></body></html>',
        },
      );

      final reconciled = await reconciler.reconcile(
        toc: const <BookTocItem>[],
        readingOrder: const <BookAssetItem>[
          BookAssetItem(
            id: 'chapter_1',
            href: 'Text/ch1.xhtml',
            mediaType: 'application/xhtml+xml',
          ),
          BookAssetItem(
            id: 'chapter_2',
            href: 'Text/ch2.xhtml',
            mediaType: 'application/xhtml+xml',
          ),
        ],
        resourceSource: source,
        contentRoot: 'OEBPS',
      );

      expect(reconciled.map((item) => item.title), <String>[
        'Opening',
        'Middle',
      ]);
      expect(reconciled.map((item) => item.href), <String>[
        'OEBPS/Text/ch1.xhtml',
        'OEBPS/Text/ch2.xhtml',
      ]);
      expect(reconciled.map((item) => item.order), <int>[0, 1]);
    });
  });
}

class _MemoryResourceSource implements BookResourceSource {
  _MemoryResourceSource({required Map<String, String> files})
    : _files = files.map(
        (key, value) => MapEntry(
          PathUtils.normalizeRelative(key),
          Uint8List.fromList(utf8.encode(value)),
        ),
      );

  final Map<String, Uint8List> _files;

  @override
  String get sourceId => 'memory';

  @override
  Future<void> close() async {}

  @override
  String? contentTypeFor(String relativePath) {
    return MimeUtils.byPath(relativePath);
  }

  @override
  Future<bool> exists(String relativePath) async {
    return _files.containsKey(PathUtils.normalizeRelative(relativePath));
  }

  @override
  Future<List<String>> listPaths() async {
    final paths = _files.keys.toList(growable: false)..sort();
    return paths;
  }

  @override
  Future<Uint8List?> readBytes(String relativePath) async {
    return _files[PathUtils.normalizeRelative(relativePath)];
  }

  @override
  Future<String?> readText(
    String relativePath, {
    Encoding encoding = utf8,
  }) async {
    final bytes = await readBytes(relativePath);
    if (bytes == null) {
      return null;
    }
    return encoding.decode(bytes);
  }
}
