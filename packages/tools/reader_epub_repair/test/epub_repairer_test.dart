import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:reader_epub_repair/reader_epub_repair.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('EpubRepairer', () {
    test(
      'preserves a valid navigation document without spine completion',
      () async {
        final root = await Directory.systemTemp.createTemp('epub_repair_test_');
        addTearDown(() => root.delete(recursive: true));
        final input = File('${root.path}/input.epub');
        final output = '${root.path}/output.epub';
        await input.writeAsBytes(_sampleEpub());

        final result = await const EpubRepairer().repair(
          input.path,
          outputPath: output,
        );

        expect(result.changed, isFalse);
        final archive = ZipDecoder().decodeBytes(
          await File(output).readAsBytes(),
        );
        final nav = archive.find('OEBPS/nav.xhtml')!.content;
        final navDocument = XmlDocument.parse(String.fromCharCodes(nav));
        expect(navDocument.findAllElements('a').map((e) => e.innerText), [
          'Part 1',
          'Part 2',
        ]);
      },
    );

    test('repairs XML-valid XHTML that is missing Sigil DOCTYPE', () async {
      final root = await Directory.systemTemp.createTemp('epub_repair_test_');
      addTearDown(() => root.delete(recursive: true));
      final input = File('${root.path}/input.epub');
      final output = '${root.path}/output.epub';
      await input.writeAsBytes(_sampleEpub(includeDoctype: false));

      final result = await const EpubRepairer().repair(
        input.path,
        outputPath: output,
      );

      expect(result.changed, isTrue);
      expect(
        result.issues.where((issue) => issue.code == 'missing_doctype'),
        hasLength(3),
      );
      final archive = ZipDecoder().decodeBytes(
        await File(output).readAsBytes(),
      );
      final document = XmlDocument.parse(
        String.fromCharCodes(archive.find('OEBPS/Text/one.xhtml')!.content),
      );
      expect(document.doctypeElement?.name, 'html');
    });

    test('repairs malformed XHTML and keeps SVG namespaces', () async {
      final root = await Directory.systemTemp.createTemp('epub_repair_test_');
      addTearDown(() => root.delete(recursive: true));
      final input = File('${root.path}/input.epub');
      final output = '${root.path}/output.epub';
      await input.writeAsBytes(_malformedXhtmlEpub());

      final result = await const EpubRepairer().repair(
        input.path,
        outputPath: output,
      );

      expect(result.changed, isTrue);
      final archive = ZipDecoder().decodeBytes(
        await File(output).readAsBytes(),
      );
      final xhtml = String.fromCharCodes(
        archive.find('OEBPS/Text/chapter.xhtml')!.content,
      );
      final document = XmlDocument.parse(xhtml);
      expect(document.findAllElements('svg'), isNotEmpty);
      expect(xhtml, contains('xlink:href="image.svg"'));
    });

    test('standardizes paths and updates XHTML and CSS references', () async {
      final root = await Directory.systemTemp.createTemp('epub_repair_test_');
      addTearDown(() => root.delete(recursive: true));
      final input = File('${root.path}/input.epub');
      final output = '${root.path}/output.epub';
      await input.writeAsBytes(_standardizeEpub());

      final result = await const EpubRepairer().standardize(
        input.path,
        outputPath: output,
      );

      expect(result.changed, isTrue);
      final archive = ZipDecoder().decodeBytes(
        await File(output).readAsBytes(),
      );
      expect(archive.find('mimetype'), isNotNull);
      expect(archive.find('OEBPS/content.opf'), isNotNull);
      expect(archive.find('OEBPS/Text/chapter.xhtml'), isNotNull);
      expect(archive.find('OEBPS/Styles/book.css'), isNotNull);
      final xhtml = String.fromCharCodes(
        archive.find('OEBPS/Text/chapter.xhtml')!.content,
      );
      final css = String.fromCharCodes(
        archive.find('OEBPS/Styles/book.css')!.content,
      );
      expect(xhtml, contains('../Images/cover.png'));
      expect(xhtml, contains('../Styles/book.css'));
      expect(css, contains('../Images/cover.png'));

      final secondOutput = '${root.path}/output-second.epub';
      final second = await const EpubRepairer().standardize(
        output,
        outputPath: secondOutput,
      );
      expect(second.changed, isFalse);
    });

    test(
      'does not rewrite the supplied target fixture when it is valid',
      () async {
        const inputPath =
            r'C:\Users\Administrator\Downloads\最强废渣皇子暗中活跃于帝位之争\16_统一译名.epub';
        final input = File(inputPath);
        if (!input.existsSync()) {
          return;
        }
        final root = await Directory.systemTemp.createTemp(
          'epub_repair_target_',
        );
        addTearDown(() => root.delete(recursive: true));

        final output = '${root.path}/target.epub';
        final result = await const EpubRepairer().repair(
          input.path,
          outputPath: output,
        );

        expect(result.hasFatalIssue, isFalse);
        expect(result.changed, isFalse);
      },
    );
  });
}

List<int> _sampleEpub({bool includeDoctype = true}) {
  final archive = Archive();
  void add(String path, String value) {
    archive.addFile(ArchiveFile.string(path, value));
  }

  final doctype = includeDoctype ? '<!DOCTYPE html>' : '';

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/package.opf"/></rootfiles></container>',
  );
  add(
    'OEBPS/package.opf',
    '<?xml version="1.0"?><package version="3.0" xmlns="http://www.idpf.org/2007/opf">'
        '<metadata><dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Book</dc:title></metadata>'
        '<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
        '<item id="one" href="Text/one.xhtml" media-type="application/xhtml+xml"/>'
        '<item id="two" href="Text/two.xhtml" media-type="application/xhtml+xml"/></manifest>'
        '<spine><itemref idref="one"/><itemref idref="two"/></spine></package>',
  );
  add(
    'OEBPS/nav.xhtml',
    '<?xml version="1.0"?>$doctype<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops"><head></head><body>'
        '<nav epub:type="toc"><ol>'
        '<li><a href="Text/one.xhtml">Part 1</a></li><li><a href="Text/two.xhtml">Part 2</a></li>'
        '</ol></nav></body></html>',
  );
  add(
    'OEBPS/Text/one.xhtml',
    '$doctype<html><head></head><body><h1>One</h1></body></html>',
  );
  add(
    'OEBPS/Text/two.xhtml',
    '$doctype<html><head></head><body><h1>Two</h1></body></html>',
  );
  return ZipEncoder().encode(archive);
}

List<int> _malformedXhtmlEpub() {
  final archive = Archive();
  void add(String path, String value) {
    archive.addFile(ArchiveFile.string(path, value));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>',
  );
  add(
    'OEBPS/content.opf',
    '<?xml version="1.0"?><package version="3.0" xmlns="http://www.idpf.org/2007/opf">'
        '<manifest><item id="chapter" href="Text/chapter.xhtml" media-type="application/xhtml+xml"/>'
        '<item id="image" href="Images/image.svg" media-type="image/svg+xml"/></manifest>'
        '<spine><itemref idref="chapter"/></spine></package>',
  );
  add(
    'OEBPS/Text/chapter.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>Broken & text'
        '<svg xmlns="http://www.w3.org/2000/svg"><use xmlns:xlink="http://www.w3.org/1999/xlink" '
        'xlink:href="image.svg"></body></html>',
  );
  add('OEBPS/Images/image.svg', '<svg xmlns="http://www.w3.org/2000/svg"/>');
  return ZipEncoder().encode(archive);
}

List<int> _standardizeEpub() {
  final archive = Archive();
  void add(String path, String value) {
    archive.addFile(ArchiveFile.string(path, value));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="package.opf"/></rootfiles></container>',
  );
  add(
    'package.opf',
    '<?xml version="1.0"?><package version="3.0" xmlns="http://www.idpf.org/2007/opf">'
        '<metadata><dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Book</dc:title></metadata>'
        '<manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>'
        '<item id="style" href="book.css" media-type="text/css"/>'
        '<item id="cover" href="cover.png" media-type="image/png"/></manifest>'
        '<spine><itemref idref="chapter"/></spine></package>',
  );
  add(
    'chapter.xhtml',
    '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head>'
        '<link rel="stylesheet" href="book.css"/></head><body><img src="cover.png"/>'
        '</body></html>',
  );
  add('book.css', 'body { background-image: url("cover.png"); }');
  archive.addFile(
    ArchiveFile.bytes('cover.png', Uint8List.fromList(<int>[0, 1, 2])),
  );
  return ZipEncoder().encode(archive);
}
