// golden_dump —— 为 Rust core 重构导出“字节参照”的 dev-only 工具。
//
// 用法:cd omni-reader/dev_tools/golden_dump && dart run bin/golden_dump.dart <outDir>
// 产出(outDir 下):
//   fixtures/sample.epub          自建样书(覆盖 generator 各规则分支)
//   goldens/epub/manifest.json    完整形态(含三条 links)
//   goldens/epub/manifest.engine.json  引擎落盘裁剪形态(去 search/content.json link)
//   goldens/epub/positions.json
//   goldens/epub/content.json
//   json_probe.txt                 JSON 边界行为探针(供 core ser 规则回填)
//
// 仅作 Rust core 字节兼容验证的真值来源,不进 melos workspace、不入发布面。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:reader_parser_epub/reader_parser_epub.dart';

Future<void> main(List<String> args) async {
  final outDir = args.isNotEmpty ? args[0] : 'out';
  final fixturesDir = p.join(outDir, 'fixtures');
  final goldensDir = p.join(outDir, 'goldens', 'epub');
  Directory(fixturesDir).createSync(recursive: true);
  Directory(goldensDir).createSync(recursive: true);

  // 1. 样书
  final sampleBytes = _buildSampleEpub();
  File(p.join(fixturesDir, 'sample.epub'))
      .writeAsBytesSync(sampleBytes, flush: true);

  // 2. 解析 + 生成 artifacts
  final parser = EpubParser();
  final parsed = await parser.parseFromFile(p.join(fixturesDir, 'sample.epub'));
  EpubBookPackage enriched;
  try {
    enriched = await EpubArtifactGenerator().generateArtifacts(parsed);
  } finally {
    // parseFromFile 成功后 package 持有 source;generate 返回新对象共享同一
    // source,close 一次即可。
    await parsed.close();
  }
  final artifactFiles = enriched.artifacts.toFileMap();

  final manifest = artifactFiles['manifest.json']!;
  final positions = artifactFiles['positions.json']!;
  final content = artifactFiles['content.json']!;

  final encoder = const JsonEncoder.withIndent('  ');
  File(p.join(goldensDir, 'manifest.json'))
      .writeAsStringSync('${encoder.convert(manifest)}\n', flush: true);
  File(p.join(goldensDir, 'positions.json'))
      .writeAsStringSync('${encoder.convert(positions)}\n', flush: true);
  File(p.join(goldensDir, 'content.json'))
      .writeAsStringSync('${encoder.convert(content)}\n', flush: true);

  // 3. 引擎落盘形态:manifest 去掉 search/content.json link(对齐 EpubImportService)
  final engineManifest = _removeContentSearchLink(manifest);
  File(p.join(goldensDir, 'manifest.engine.json'))
      .writeAsStringSync('${encoder.convert(engineManifest)}\n', flush: true);

  // 4. JSON 边界探针(供 core ser 规则回填)
  File(p.join(outDir, 'json_probe.txt')).writeAsStringSync(_jsonProbe());

  stdout.writeln('golden_dump: wrote $outDir');
}

/// 去掉 manifest 中指向 content.json/search 的 link;若 links 空则移除 links 键。
/// 对齐 EpubImportService._removeContentSearchLink 的判定。
Map<String, Object?> _removeContentSearchLink(Map<String, Object?> manifestJson) {
  final out = Map<String, Object?>.from(manifestJson);
  final rawLinks = out['links'];
  if (rawLinks is! List) {
    return out;
  }
  final filtered = rawLinks
      .whereType<Map>()
      .map((link) => link.map((key, value) => MapEntry('$key', value)))
      .where((link) {
    final rel = '${link['rel'] ?? ''}'.trim().toLowerCase();
    final href = '${link['href'] ?? ''}'.trim().toLowerCase();
    return rel != 'search' && href != 'content.json';
  }).toList(growable: false);
  if (filtered.isEmpty) {
    out.remove('links');
  } else {
    out['links'] = filtered;
  }
  return out;
}

/// 一次性 JSON 边界行为探针:Dart jsonEncode 在哪些字符/数值上怎么输出。
/// 输出供 core 的 Dart 兼容 writer 规则对齐(见 core/docs/03 §8 台账)。
String _jsonProbe() {
  final b = StringBuffer();
  void line(String label, Object? value) {
    b.writeln('$label => ${jsonEncode(value)}');
  }

  // 非有限 double:jsonEncode 会抛错,单独记录行为
  for (final v in <Object?>[
    double.nan,
    double.infinity,
    double.negativeInfinity,
  ]) {
    try {
      jsonEncode(v);
      b.writeln('num_$v => <ok>');
    } catch (e) {
      b.writeln('num_$v => <throws ${e.runtimeType}>');
    }
  }

  line('nul_escape', '\u0000'); // \u0000
  line('ctrl_escape', '\u0001\u001f'); // \u0001 \u001f
  line('quote_backslash', '"\\'); // \" \\
  line('solidus', '/'); // 斜杠:转义?
  line('backspace_ff', '\b\f'); // \b \f
  line('newline_rt', '\n\r\t'); // \n \r \t
  line('nbsp', '\u00a0'); // NBSP:字面或 \u?
  line('c1_0080', '\u0080'); // C1
  line('u2028', '\u2028'); // 行分隔符
  line('u2029', '\u2029'); // 段分隔符
  line('u202f', '\u202f'); // 窄 NBSP
  line('u00e9', '\u00e9'); // é
  line('u4e2d', '中'); // CJK
  line('u1f600', '\u{1f600}'); // emoji(surrogate pair)
  line('u_e000_pua', '\ue000'); // PUA
  line('control_u007f', '\u007f'); // DEL
  line('lt_gt_amp', '<>&'); // < > &
  line('apos', "'"); // '
  line('eq', '='); // =

  // 数值:直接放 jsonEncode,看 double 序列化(整数补 .0 / 科学计数)
  for (final v in <Object?>[
    0.0,
    1.0,
    -1.0,
    0.5,
    0.14285714285714285,
    1 / 3,
    123456789.0,
    0.000001,
    1e-7,
    1e21,
    123456789012345678901234567890.0,
    -0.0,
  ]) {
    line('num_$v', v);
  }

  // Map 键序保留?空 map / null 值键
  b.writeln('map_order => ${jsonEncode(<String, Object?>{
        'z': 1,
        'a': 2,
        'm': 3,
      })}');
  b.writeln('map_null_value => ${jsonEncode(<String, Object?>{'k': null})}');
  b.writeln('empty_list => ${jsonEncode(<Object?>[])}');
  b.writeln('empty_map => ${jsonEncode(<String, Object?>{})}');
  b.writeln('list_null => ${jsonEncode(<Object?>[null, 1])}');

  // double 的 toString 形态(与 jsonEncode 是否一致)
  b.writeln('dbl_tostr_0 => ${0.0.toString()}');
  b.writeln('dbl_tostr_1e-7 => ${(1e-7).toString()}');
  b.writeln('dbl_tostr_142857 => ${(0.14285714285714285).toString()}');
  b.writeln('dbl_tostr_1e21 => ${(1e21).toString()}');
  b.writeln('dbl_tostr_minus0 => ${(-0.0).toString()}');
  b.writeln('dbl_tostr_1_5 => ${(1.5).toString()}');
  b.writeln('dbl_tostr_0_000001 => ${(0.000001).toString()}');
  b.writeln('int_inside_double => ${(123.0).toString()}');

  return b.toString();
}

// ---- 样书构建 ----

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

void _addText(Archive archive, String path, String content) {
  archive.addFile(ArchiveFile(path, utf8.encode(content).length, _utf8(content)));
}

/// 构造一个覆盖 generator 各规则分支的样书:
/// - 5 个 spine 章(含标题章 h1、正文 p/li/blockquote、长文章 >1024 触发多 position、
///   段落 >2000 触发 content 分块、img、NBSP/多空白、嵌套 nav toc、NCX 文件
///   [测试 nav 权威,不会被用到]、封面 PNG、多作者/多 subject/description/rights、
///   cover meta)。
Uint8List _buildSampleEpub() {
  final archive = Archive();
  _addText(archive, 'mimetype', 'application/epub+zip');
  _addText(
    archive,
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
  _addText(
    archive,
    'OEBPS/content.opf',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="BookId">urn:isbn:9780000000001</dc:identifier>
    <dc:title>Golden Sample Book</dc:title>
    <dc:creator>First Author</dc:creator>
    <dc:creator>Second Author</dc:creator>
    <dc:language>zh</dc:language>
    <dc:publisher>Omni Press</dc:publisher>
    <dc:date>2024-01-02</dc:date>
    <dc:description>A book used to pin byte output.</dc:description>
    <dc:subject>Fiction</dc:subject>
    <dc:subject>Drama</dc:subject>
    <dc:rights>Public Domain</dc:rights>
    <meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-img" href="Images/cover.png" media-type="image/png"/>
    <item id="css" href="Styles/main.css" media-type="text/css"/>
    <item id="titlepage" href="Text/titlepage.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="Text/ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch3" href="Text/ch3.xhtml" media-type="application/xhtml+xml"/>
    <item id="backmatter" href="Text/backmatter.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="titlepage"/>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="ch3"/>
    <itemref idref="backmatter"/>
  </spine>
</package>
''',
  );
  _addText(
    archive,
    'OEBPS/nav.xhtml',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <head><title>Nav</title></head>
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="Text/titlepage.xhtml">Title Page</a>
          <ol>
            <li><a href="Text/ch1.xhtml#s1">Chapter 1 Section 1</a></li>
          </ol>
        </li>
        <li><a href="Text/ch1.xhtml">Chapter One</a></li>
        <li><a href="Text/ch2.xhtml">Chapter Two</a></li>
        <li><a href="Text/ch3.xhtml">Chapter Three</a></li>
        <li><a href="Text/backmatter.xhtml">Backmatter</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
  );
  _addText(
    archive,
    'OEBPS/toc.ncx',
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
    '<head></head><docTitle><text>Golden Sample</text></docTitle>'
    '<navMap>'
    '<navPoint id="ncx1"><navLabel><text>NCX One</text></navLabel>'
    '<content src="Text/ch1.xhtml"/></navPoint>'
    '</navMap>'
    '</ncx>',
  );

  // 极小 PNG(1x1 透明)作封面,验证二进制资源 + 非 HTML spine 不参与 artifact
  _addText(
    archive,
    'OEBPS/Images/cover.png',
    _tinyPngBase64,
  );
  _addText(
    archive,
    'OEBPS/Styles/main.css',
    'body { margin: 0; }\n',
  );

  // titlepage:仅 h1 与封面 img(cover meta 指向它,img 是 locatable,textLength 0)
  _addText(
    archive,
    'OEBPS/Text/titlepage.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Title</title></head>'
    '<body><h1>Golden Sample Book</h1>'
    '<img src="../Images/cover.png" alt="cover"/>'
    '<p>Some intro paragraph with <b>bold</b> and <i>italic</i>.</p>'
    '</body></html>',
  );

  // ch1:多 h2、段落、li、blockquote;含 NBSP 与多空白;文本 < 1024
  _addText(
    archive,
    'OEBPS/Text/ch1.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter 1</title></head>'
    '<body><h1>Chapter One</h1>'
    '<p>This is the first paragraph.\u00a0 It has an NBSP and'
    '   some   extra   whitespace.</p>'
    '<p>Second paragraph with a\nnewline and\ttab.</p>'
    '<blockquote>A quoted line.</blockquote>'
    '<ul><li>Item  one</li><li>Item  two</li></ul>'
    '<h2 id="s1">Section 1</h2>'
    '<p>Section one body text.</p>'
    '</body></html>',
  );

  // ch2:正文超过 1024 字符 → 触发多 position;段落约 1500 字符
  // (超过 contentBlock 的 2000 留到 ch3,这里只触发多 position)
  final ch2Body = StringBuffer('''
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter 2</title></head><body>
''');
  ch2Body.write('<h1>Chapter Two</h1>');
  // ~1500 字符长段落(英文词 + 空格,约 210 词)
  final lorem = List<String>.generate(
    60,
    (i) => 'word${i.toString().padLeft(3, '0')}',
  ).join(' ');
  ch2Body.write('<p>');
  for (var i = 0; i < 30; i++) {
    if (i > 0) {
      ch2Body.write(' ');
    }
    ch2Body.write(lorem);
  }
  ch2Body.write('</p>');
  ch2Body.write('</body></html>');
  _addText(archive, 'OEBPS/Text/ch2.xhtml', ch2Body.toString());

  // ch3:一个 >2000 字符段落 → 触发 content 分块(也 >1024 触发多 position)
  final ch3Body = StringBuffer(
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter 3</title></head><body>',
  );
  ch3Body.write('<h1>Chapter Three</h1>');
  ch3Body.write('<p>');
  final word = 'word ';
  // 2400 字符
  for (var i = 0; i < 2400; i++) {
    ch3Body.write(word);
  }
  ch3Body.write('</p>');
  ch3Body.write('</body></html>');
  _addText(archive, 'OEBPS/Text/ch3.xhtml', ch3Body.toString());

  // backmatter:无标题正文 → 只有 p,无 h
  _addText(
    archive,
    'OEBPS/Text/backmatter.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Backmatter</title></head>'
    '<body><p>The end of the book.</p></body></html>',
  );

  final bytes = ZipEncoder().encode(archive);
  return Uint8List.fromList(bytes);
}

// 1x1 透明 PNG(固定字节,避免依赖图片资源文件)
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
