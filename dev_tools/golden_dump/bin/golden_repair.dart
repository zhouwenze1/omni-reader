// golden_repair —— 段 C:导出 epub_repair 的字节参照(供 Rust omni-repair compat)。
//
// 用法:cd omni-reader/dev_tools/golden_dump && dart run bin/golden_repair.dart <outDir>
// 产出(outDir 下):
//   goldens/xhtml/<case>.txt              repairMalformedXhtml 纯函数逐字节输出
//   goldens/xhtml/<case>.input.html       输入(便于对照)
//   goldens/epub_repair/<case>/files/…    repair/standardize 输出 zip 解压后的条目集
//   goldens/epub_repair/<case>/result.json changed/issues/changes 摘要
//
// 仅作 Rust core 字节兼容验证真值来源。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:reader_epub_repair/reader_epub_repair.dart';

Future<void> main(List<String> args) async {
  final outDir = args.isNotEmpty ? args[0] : 'out';
  final xhtmlDir = p.join(outDir, 'goldens', 'xhtml');
  final bookDir = p.join(outDir, 'goldens', 'epub_repair');
  Directory(xhtmlDir).createSync(recursive: true);
  Directory(bookDir).createSync(recursive: true);

  // 1. serializer 纯函数 golden(全小写规范输入)
  final serializerCases = <String, ({String input, String? version})>{
    'doctype_insert': (
      input: '<html><head><title>T</title></head><body><p>Hi</p></body></html>',
      version: null,
    ),
    'no_doctype_bare_amp': (
      input: '<html><body><p>Broken & text</p></body></html>',
      version: null,
    ),
    'unclosed_svg_use': (
      input: '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>Broken & text'
          '<svg xmlns="http://www.w3.org/2000/svg"><use xmlns:xlink="http://www.w3.org/1999/xlink" '
          'xlink:href="image.svg"></body></html>',
      version: null,
    ),
    'svg_selfclosing': (
      input: '<html><body><svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg></body></html>',
      version: null,
    ),
    'void_and_empty': (
      input: '<html><body><p>a<br>b<img src="x.png"/><span></span><div></div></p></body></html>',
      version: null,
    ),
    'comment_dashes': (
      input: '<html><body><!-- a -- b --><p>x</p></body></html>',
      version: null,
    ),
    'entities': (
      input: '<html><body><p>&amp; &lt; &gt; &quot; &nbsp; &#233; &copy;</p></body></html>',
      version: null,
    ),
    'cdata_as_comment': (
      input: '<html><body><p>a<![CDATA[ raw ]]></p></body></html>',
      version: null,
    ),
    'text_gt': (
      input: '<html><body><p>a > b < c</p></body></html>',
      version: null,
    ),
    'attr_escape': (
      input: '<html><body><a href="x?a=1&amp;b=2&lt;3&quot;4">l</a></body></html>',
      version: null,
    ),
    'xhtml11_version2': (
      input: '<html><head><title>T</title></head><body><p>v2</p></body></html>',
      version: '2.0',
    ),
    'version3': (
      input: '<html><head><title>T</title></head><body><p>v3</p></body></html>',
      version: '3.0',
    ),
    'implicit_root_head': (
      input: '<title>T</title><p>loose</p>',
      version: null,
    ),
    'nested_lists': (
      input: '<html><body><ul><li>a<ul><li>b</li></ul></li></ul></body></html>',
      version: null,
    ),
  };

  for (final entry in serializerCases.entries) {
    final caseName = entry.key;
    final input = entry.value.input;
    final version = entry.value.version;
    final output = repairMalformedXhtml(input, version: version);
    File(p.join(xhtmlDir, '$caseName.input.html'))
        .writeAsStringSync(input, flush: true);
    File(p.join(xhtmlDir, '$caseName.txt')).writeAsStringSync(output, flush: true);
  }

  // 2. 整书 repair/standardize golden
  // 样书与 Dart 测试 fixture 一致(见 epub_repairer_test.dart)
  final bookCases = <String, ({List<int> Function() build, bool standardize})>{
    'healthy': (build: _sampleEpub, standardize: false),
    'missing_doctype': (build: () => _sampleEpub(includeDoctype: false), standardize: false),
    'malformed_xhtml': (build: _malformedXhtmlEpub, standardize: false),
    'standardize_flat': (build: _standardizeEpub, standardize: true),
  };

  for (final entry in bookCases.entries) {
    final caseName = entry.key;
    final build = entry.value.build;
    final doStandardize = entry.value.standardize;
    final caseDir = p.join(bookDir, caseName);
    final filesDir = p.join(caseDir, 'files');
    Directory(filesDir).createSync(recursive: true);

    final root = Directory.systemTemp.createTempSync('golden_repair_');
    try {
      final input = p.join(root.path, 'input.epub');
      final output = p.join(root.path, 'output.epub');
      File(input).writeAsBytesSync(build(), flush: true);

      final repairer = const EpubRepairer();
      final result = doStandardize
          ? await repairer.standardize(input, outputPath: output)
          : await repairer.repair(input, outputPath: output);

      // 结果摘要
      final summary = <String, Object?>{
        'changed': result.changed,
        'hasFatalIssue': result.hasFatalIssue,
        'issues': result.issues.map((i) => i.toJson()).toList(),
        'changes': result.changes.map((c) => c.toJson()).toList(),
      };
      File(p.join(caseDir, 'result.json'))
          .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(summary)}\n',
              flush: true);

      // 输出 zip 解压为条目集(便于逐条目对照)
      final outBytes = File(output).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(outBytes);
      for (final file in archive.files) {
        if (file.isFile) {
          final content = file.content as List<int>;
          final target = p.join(filesDir, file.name);
          Directory(p.dirname(target)).createSync(recursive: true);
          File(target).writeAsBytesSync(content, flush: true);
        }
      }
      // mimetype 是否首位 + stored(archive 4.x:CompressionType.none = store)
      final first = archive.files.isNotEmpty ? archive.files.first.name : null;
      final mimetypeStored = archive.files
          .where((f) => f.name == 'mimetype')
          .every((f) => f.compression == CompressionType.none);
      File(p.join(caseDir, 'zip_meta.json')).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'firstEntry': first,
          'mimetypeStored': mimetypeStored,
        }),
        flush: true,
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  }

  stdout.writeln('golden_repair: wrote $outDir');
}

// ---- 样书(与 Dart epub_repairer_test.dart fixture 一致) ----

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
