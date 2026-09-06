import 'dart:convert';
import 'dart:typed_data';

import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:reader_parser_epub/reader_parser_epub.dart';
import 'package:test/test.dart';

void main() {
  test('treats navigation as authoritative without spine completion', () async {
    final source = _MemoryResourceSource(<String, String>{
      'mimetype': 'application/epub+zip',
      'META-INF/container.xml': '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles>
</container>
''',
      'OEBPS/content.opf': '''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Book</dc:title></metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="part1" href="Text/part1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="part1"/><itemref idref="chapter1"/></spine>
</package>
''',
      'OEBPS/nav.xhtml': '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body><nav epub:type="toc"><ol>
    <li><a href="Text/part1.xhtml">Part 1</a></li>
  </ol></nav></body>
</html>
''',
      'OEBPS/Text/part1.xhtml': '<html><body><h1>Part 1</h1></body></html>',
      'OEBPS/Text/chapter1.xhtml':
          '<html><body><h1>Chapter 1</h1></body></html>',
    });

    final package = await EpubParser().parseFromSource(source);
    addTearDown(package.close);

    expect(package.readingOrder, hasLength(2));
    expect(package.toc.map((item) => item.title), ['Part 1']);
    expect(package.toc.single.href, 'OEBPS/Text/part1.xhtml');
  });
}

class _MemoryResourceSource implements BookResourceSource {
  _MemoryResourceSource(Map<String, String> files)
    : _files = files.map(
        (path, content) => MapEntry(
          PathUtils.normalizeRelative(path),
          Uint8List.fromList(utf8.encode(content)),
        ),
      );

  final Map<String, Uint8List> _files;

  @override
  String get sourceId => 'memory';

  @override
  Future<void> close() async {}

  @override
  String? contentTypeFor(String relativePath) => MimeUtils.byPath(relativePath);

  @override
  Future<bool> exists(String relativePath) async =>
      _files.containsKey(PathUtils.normalizeRelative(relativePath));

  @override
  Future<List<String>> listPaths() async => _files.keys.toList(growable: false);

  @override
  Future<Uint8List?> readBytes(String relativePath) async =>
      _files[PathUtils.normalizeRelative(relativePath)];

  @override
  Future<String?> readText(
    String relativePath, {
    Encoding encoding = utf8,
  }) async {
    final bytes = await readBytes(relativePath);
    return bytes == null ? null : encoding.decode(bytes);
  }
}
