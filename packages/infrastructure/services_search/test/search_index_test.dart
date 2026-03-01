import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:services_search/services_search.dart';
import 'package:test/test.dart';

void main() {
  group('ParagraphSegmenter', () {
    test('splits html by lines and removes empty paragraphs', () {
      const segmenter = ParagraphSegmenter();
      const input = '''
<h1>Title</h1>
<p>First line</p>

<p>Second line<br/>continue</p>

Third line
''';

      final paragraphs = segmenter.segment(input, minParagraphLength: 2);

      expect(paragraphs, hasLength(5));
      expect(paragraphs[0], contains('Title'));
      expect(paragraphs[1], contains('First line'));
      expect(paragraphs[2], contains('Second line'));
      expect(paragraphs[3], equals('continue'));
      expect(paragraphs[4], equals('Third line'));
    });
  });

  group('EpubSearchService with fake chapters', () {
    test('returns hits with snippet and applies limit/contextChars', () async {
      final service = EpubSearchService(index: MemorySearchIndex());

      await service.ensureIndexedFromChapters(
        bookId: 'book-a',
        chapters: const <ChapterText>[
          ChapterText(
            spineIndex: 0,
            href: 'Text/chapter1.xhtml',
            cfi: 'epubcfi(/6/2)',
            text:
                'Chapter 1\nA galaxy appears in the sky.\nAnother galaxy appears.',
          ),
          ChapterText(
            spineIndex: 1,
            href: 'Text/chapter2.xhtml',
            cfi: 'epubcfi(/6/4)',
            text: 'Chapter 2\nNo keyword here.',
          ),
        ],
      );

      final shortHits = await service.search(
        const SearchQuery(
          bookId: 'book-a',
          query: 'galaxy',
          contextChars: 3,
          limit: 1,
        ),
      );

      final longHits = await service.search(
        const SearchQuery(
          bookId: 'book-a',
          query: 'galaxy',
          contextChars: 10,
          limit: 10,
        ),
      );

      expect(shortHits, hasLength(1));
      expect(longHits.length, greaterThanOrEqualTo(2));
      expect(shortHits.first.snippet, contains('galaxy'));
      expect(shortHits.first.href, isNotEmpty);
      expect(shortHits.first.cfi, isNotNull);
      expect(
        shortHits.first.snippet.length,
        lessThan(longHits.first.snippet.length),
      );
    });
  });

  group('EpubSearchService with real epub file', () {
    test('reads epub file, builds index on demand and returns CFI', () async {
      final service = EpubSearchService(index: MemorySearchIndex());
      final tempDir =
          await Directory.systemTemp.createTemp('services_search_epub_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final filePath = '${tempDir.path}${Platform.pathSeparator}sample.epub';
      final epubFile = File(filePath);
      await epubFile.writeAsBytes(
        _createTestEpub(
          chapterBodies: const <String>[
            '<h1>One</h1><p>The galaxy starts here.</p>',
            '<h1>Two</h1><p>Another galaxy appears later.</p>',
          ],
        ),
        flush: true,
      );
      expect(await epubFile.exists(), isTrue);

      final bytes = await epubFile.readAsBytes();
      expect(bytes, isNotEmpty);

      final hits = await service.search(
        const SearchQuery(
          bookId: 'epub-book',
          query: 'galaxy',
          limit: 10,
          contextChars: 12,
        ),
        epubBytes: bytes,
        includeParagraphText: true,
      );

      expect(hits.length, greaterThanOrEqualTo(2));
      for (final hit in hits) {
        expect(hit.href, isNotEmpty);
        expect(hit.snippet, contains('galaxy'));
        expect(hit.cfi, isNotNull);
        expect(hit.cfi, startsWith('epubcfi('));
        expect(hit.paragraphText, isNotNull);
      }
    });
  });
}

Uint8List _createTestEpub({required List<String> chapterBodies}) {
  final archive = Archive();

  archive.addFile(
    ArchiveFile(
      'mimetype',
      'application/epub+zip'.length,
      'application/epub+zip'.codeUnits,
    ),
  );

  const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  archive.addFile(
    ArchiveFile(
      'META-INF/container.xml',
      containerXml.length,
      containerXml.codeUnits,
    ),
  );

  final manifestItems = <String>[
    '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    for (var i = 0; i < chapterBodies.length; i++)
      '<item id="chapter${i + 1}" href="chapter${i + 1}.xhtml" media-type="application/xhtml+xml"/>',
  ].join('\n    ');
  final spineItems = <String>[
    for (var i = 0; i < chapterBodies.length; i++)
      '<itemref idref="chapter${i + 1}"/>',
  ].join('\n    ');

  final opf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Search Test Book</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:identifier id="BookId">search-test-book-id</dc:identifier>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    $manifestItems
  </manifest>
  <spine toc="ncx">
    $spineItems
  </spine>
</package>''';
  archive.addFile(ArchiveFile('OEBPS/content.opf', opf.length, opf.codeUnits));

  final navPoints = <String>[
    for (var i = 0; i < chapterBodies.length; i++)
      '''
    <navPoint id="navPoint-${i + 1}" playOrder="${i + 1}">
      <navLabel><text>Chapter ${i + 1}</text></navLabel>
      <content src="chapter${i + 1}.xhtml"/>
    </navPoint>''',
  ].join('\n');
  final toc = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="search-test-book-id"/>
  </head>
  <docTitle>
    <text>Search Test Book</text>
  </docTitle>
  <navMap>
    $navPoints
  </navMap>
</ncx>''';
  archive.addFile(ArchiveFile('OEBPS/toc.ncx', toc.length, toc.codeUnits));

  for (var i = 0; i < chapterBodies.length; i++) {
    final html = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter ${i + 1}</title></head>
<body>${chapterBodies[i]}</body>
</html>''';
    archive.addFile(
      ArchiveFile('OEBPS/chapter${i + 1}.xhtml', html.length, html.codeUnits),
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}
