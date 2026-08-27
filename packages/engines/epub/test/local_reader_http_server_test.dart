import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalReaderHttpServer', () {
    test('serves book resources from lazy zip archive', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'local_reader_http_server_test_',
      );
      addTearDown(() async {
        await LocalReaderHttpServer.instance.stop();
        await tempRoot.delete(recursive: true);
      });

      final epubPath = p.join(tempRoot.path, 'sample.epub');
      await File(epubPath).writeAsBytes(_buildSampleEpubBytes(), flush: true);

      final storage = BookStorageService(
        booksRootPath: p.join(tempRoot.path, 'books'),
      );
      final importService = EpubImportService(storageService: storage);
      final package = await importService.importEpub(
        epubFilePath: epubPath,
        bookUuid: 'book_1',
      );

      await LocalReaderHttpServer.instance.ensureStarted(
        booksRootPath: storage.booksRootPath,
        activeBookUuid: package.bookUuid,
        activeContentRoot: package.contentRoot,
      );

      final client = HttpClient();
      addTearDown(client.close);

      final activeResponse = await _readTextResponse(
        client,
        Uri.parse(
          'http://127.0.0.1:${LocalReaderHttpServer.instance.port}/Text/ch1.xhtml',
        ),
      );
      expect(activeResponse.statusCode, HttpStatus.ok);
      expect(activeResponse.body, contains('Chapter 1'));

      final directBookResponse = await _readTextResponse(
        client,
        Uri.parse(
          'http://127.0.0.1:${LocalReaderHttpServer.instance.port}/book/${package.bookUuid}/Text/ch2.xhtml',
        ),
      );
      expect(directBookResponse.statusCode, HttpStatus.ok);
      expect(directBookResponse.body, contains('Chapter 2'));

      final healthResponse = await _readTextResponse(
        client,
        Uri.parse(
          'http://127.0.0.1:${LocalReaderHttpServer.instance.port}/health',
        ),
      );
      expect(healthResponse.statusCode, HttpStatus.ok);
      expect(healthResponse.body, contains('book.epub'));
    });
  });
}

Future<_TextResponse> _readTextResponse(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  final body = await response.transform(SystemEncoding().decoder).join();
  return _TextResponse(statusCode: response.statusCode, body: body);
}

class _TextResponse {
  const _TextResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
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
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="Text/ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
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
        <li><a href="Text/ch2.xhtml">Chapter 2</a></li>
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
  addText(
    'OEBPS/Text/ch2.xhtml',
    '<html><head><title>Chapter 2</title></head><body><h1>Chapter 2</h1></body></html>',
  );

  return ZipEncoder().encode(archive);
}
