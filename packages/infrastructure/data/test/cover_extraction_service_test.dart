import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_data/data.dart';
import 'package:path/path.dart' as p;

void main() {
  group('CoverExtractionService', () {
    test('extracts cover image from book.epub into library storage', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cover_extraction_service_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final storagePaths = StoragePaths.forTesting(baseDir: tempRoot);
      final bookStorageService = BookStorageService(
        booksRootPath: storagePaths.booksRoot.path,
      );
      final importService =
          EpubImportService(storageService: bookStorageService);
      final coverExtractionService = CoverExtractionService(
        storagePaths: storagePaths,
      );

      final epubPath = p.join(tempRoot.path, 'sample.epub');
      final coverBytes = Uint8List.fromList(<int>[137, 80, 78, 71, 1, 2, 3, 4]);
      await File(epubPath).writeAsBytes(
        _buildSampleEpubBytes(coverBytes),
        flush: true,
      );

      final package = await importService.importEpub(
        epubFilePath: epubPath,
        bookUuid: 'book_1',
      );

      final tempBookDir =
          p.join(storagePaths.libraryRoot.path, '.tmp', 'book_1');
      await Directory(tempBookDir).create(recursive: true);

      final coverRelPath =
          await coverExtractionService.extractEpubCoverToLibraryTemp(
        bookUid: 'book_1',
        opfPath: package.opfPath,
        tempBookDir: tempBookDir,
      );

      expect(coverRelPath, 'cover.png');
      final coverFile = File(p.join(tempBookDir, coverRelPath!));
      expect(await coverFile.exists(), isTrue);
      expect(await coverFile.readAsBytes(), coverBytes);
    });
  });
}

List<int> _buildSampleEpubBytes(Uint8List coverBytes) {
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

  archive.addFile(
    ArchiveFile(
        'mimetype', 'application/epub+zip'.length, 'application/epub+zip'),
  );
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
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chapter-1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-image" href="Images/cover.png" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="chapter-1"/>
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
        <li><a href="Text/ch1.xhtml">Chapter 1</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
  );
  addText(
    'OEBPS/Text/ch1.xhtml',
    '<html><head><title>Chapter 1</title></head><body><h1>Chapter 1</h1></body></html>',
  );
  archive.addFile(
      ArchiveFile('OEBPS/Images/cover.png', coverBytes.length, coverBytes));

  return ZipEncoder().encode(archive)!;
}
