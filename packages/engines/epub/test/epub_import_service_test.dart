import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('EpubImportService', () {
    test('respects smart toc reconciliation switch during import', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'epub_import_service_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final epubPath = p.join(tempRoot.path, 'sample.epub');
      await File(epubPath).writeAsBytes(_buildSampleEpubBytes(), flush: true);

      final storage = BookStorageService(
        booksRootPath: p.join(tempRoot.path, 'books'),
      );
      final service = EpubImportService(storageService: storage);

      final smartPackage = await service.importEpub(
        epubFilePath: epubPath,
        bookUuid: 'smart_on',
        enableSmartTocReconciliation: true,
      );
      final plainPackage = await service.importEpub(
        epubFilePath: epubPath,
        bookUuid: 'smart_off',
        enableSmartTocReconciliation: false,
      );

      expect(smartPackage.spineItems.length, 5);
      expect(plainPackage.spineItems.length, 5);
      expect(smartPackage.title, 'Sample Book');
      expect(smartPackage.authors, isEmpty);
      expect(
        File(storage.positionsFilePath('smart_on')).existsSync(),
        isTrue,
      );
      expect(
        File(storage.manifestFilePath('smart_on')).existsSync(),
        isTrue,
      );
      expect(
        File(storage.contentFilePath('smart_on')).existsSync(),
        isTrue,
      );

      expect(smartPackage.toc.map((item) => item.title), <String>[
        'Part 1',
        'Chapter 1',
        'Chapter 2',
        'Part 2',
        'Chapter 3',
      ]);
      expect(smartPackage.toc.map((item) => item.level), <int>[0, 1, 1, 0, 1]);
      expect(smartPackage.toc.map((item) => item.parentId), <String?>[
        null,
        'toc_0',
        'toc_0',
        null,
        'toc_1',
      ]);

      expect(plainPackage.toc.map((item) => item.title), <String>[
        'Part 1',
        'Part 2',
      ]);
      expect(plainPackage.toc.map((item) => item.level), <int>[0, 0]);
    });
  });
}

List<int> _buildSampleEpubBytes() {
  final archive = Archive();

  void addText(String path, String content) {
    archive.addFile(
      ArchiveFile(
        path,
        content.codeUnits.length,
        Uint8List.fromList(content.codeUnits),
      ),
    );
  }

  addText('mimetype', 'application/epub+zip');
  addText(
    'META-INF/container.xml',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''',
  );
  addText(
    'OEBPS/content.opf',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="BookId">sample-book</dc:identifier>
    <dc:title>Sample Book</dc:title>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="part1" href="Text/part1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="Text/ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="part2" href="Text/part2.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch3" href="Text/ch3.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="part1"/>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="part2"/>
    <itemref idref="ch3"/>
  </spine>
</package>
''',
  );
  addText(
    'OEBPS/nav.xhtml',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="Text/part1.xhtml">Part 1</a></li>
        <li><a href="Text/part2.xhtml">Part 2</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
  );

  addText(
    'OEBPS/Text/part1.xhtml',
    '<html><head><title>Part 1</title></head><body><h1>Part 1</h1></body></html>',
  );
  addText(
    'OEBPS/Text/ch1.xhtml',
    '<html><head><title>Chapter 1</title></head><body><h1>Chapter 1</h1></body></html>',
  );
  addText(
    'OEBPS/Text/ch2.xhtml',
    '<html><head><title>Chapter 2</title></head><body><h1>Chapter 2</h1></body></html>',
  );
  addText(
    'OEBPS/Text/part2.xhtml',
    '<html><head><title>Part 2</title></head><body><h1>Part 2</h1></body></html>',
  );
  addText(
    'OEBPS/Text/ch3.xhtml',
    '<html><head><title>Chapter 3</title></head><body><h1>Chapter 3</h1></body></html>',
  );

  return ZipEncoder().encode(archive)!;
}
