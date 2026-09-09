// golden_mobi —— 段 D:导出 reader_parser_mobi 反解/清洗分章的字节参照。
//
// 用法:cd omni-reader/dev_tools/golden_dump && dart run bin/golden_mobi.dart <outDir> [book.mobi]
//   - <book.mobi> 缺省取 alice(../../.mobi-ref/samples/alice.mobi);传入路径则按"combo 探针"导出。
//
// alice 产出(outDir/goldens/mobi/alice/):
//   input.mobi                    输入样书(逐字节)
//   header.json                   header 可观察字段(compression/textRecords/codepage/version/
//                                 headerLength/firstNontext/firstResource/exthFlags/huffOffset/
//                                 huffNum/extraDataFlags/hasExth + title/authors/language/asin/
//                                 description/fullName)
//   images.json                   图片槽表(index/mediaType/isCover/slotImageForRecindex 采样)
//   rawhtml.bin                   readMobi 解压拼接的正文原始流(逐字节)
//   chapters/NNNN.xhtml           逐章清洗 + 规整后的 XHTML(逐字节)
//   images/imgNNNN.ext            图片字节(逐字节)
//   toc.json                      扁平 TOC(id/title/href/order)
//
// combo 探针(outDir/goldens/mobi/combo/):chapter1.xhtml 与 recindex/图片元数据探针
// (話116-120 94MB 不入库;Rust 侧用 OMNI_MOBI_COMBO env 定位原书做语义断言)。
//
// 仅作 Rust omni-mobi 字节兼容验证真值来源;不修改任何源文件。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:reader_parser_mobi/reader_parser_mobi.dart';

Future<void> main(List<String> args) async {
  final outDir = args.isNotEmpty ? args[0] : 'out';
  final comboMode = args.length >= 2;
  final bookPath = comboMode
      ? args[1]
      : p.join('..', '..', '..', '.mobi-ref', 'samples', 'alice.mobi');
  final bytes = File(bookPath).readAsBytesSync();

  if (comboMode) {
    _exportComboProbe(outDir, bytes);
    stdout.writeln('golden_mobi(combo): wrote $outDir');
    return;
  }

  final dir = p.join(outDir, 'goldens', 'mobi', 'alice');
  Directory(dir).createSync(recursive: true);
  File(p.join(dir, 'input.mobi')).writeAsBytesSync(bytes, flush: true);

  final book = readMobi(bytes);
  final converted = convertMobiBook(book);
  final header = book.header;

  // header 观察字段
  final headerJson = <String, Object?>{
    'ident': book.container.ident,
    'sectionCount': book.container.sectionCount,
    'compression': header.compression,
    'textRecords': header.textRecords,
    'codepage': header.codepage,
    'version': header.version,
    'headerLength': header.headerLength,
    'firstNontext': header.firstNontext,
    'firstResource': header.firstResource,
    'exthFlags': header.exthFlags,
    'huffOffset': header.huffOffset,
    'huffNum': header.huffNum,
    'extraDataFlags': header.extraDataFlags,
    'hasExth': header.hasExth,
    'title': header.title,
    'authors': header.authors,
    'language': header.language,
    'asin': header.asin,
    'description': header.description,
  };
  File(p.join(dir, 'header.json'))
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(headerJson)}\n',
          flush: true);

  // rawHtml(逐字节)
  File(p.join(dir, 'rawhtml.bin'))
      .writeAsBytesSync(book.rawHtml, flush: true);

  // 图片槽表探针:采样 recindex 1..N 映射与图列表
  final probe = <String, Object?>{
    'images': [
      for (final im in book.images)
        {
          'index': im.index,
          'mediaType': im.mediaType,
          'isCover': im.isCover,
        },
    ],
    'slotSamples': {
      for (final rec in <int>[
        for (var i = 1; i <= 8; i++) i,
        for (final im in book.images) im.index,
      ])
        '$rec': () {
          final im = book.imageForRecindex(rec);
          return im == null ? null : im.index;
        }(),
    },
  };
  File(p.join(dir, 'images.json'))
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(probe)}\n',
          flush: true);

  // 逐章 XHTML
  final chaptersDir = p.join(dir, 'chapters');
  Directory(chaptersDir).createSync(recursive: true);
  for (var i = 0; i < converted.chapters.length; i++) {
    final ch = converted.chapters[i];
    File(p.join(chaptersDir, '${(i + 1).toString().padLeft(4, '0')}.xhtml'))
        .writeAsStringSync(ch.xhtml, flush: true);
  }

  // 图片字节
  final imagesDir = p.join(dir, 'images');
  Directory(imagesDir).createSync(recursive: true);
  for (final im in converted.images) {
    final name = p.basename(im.href);
    File(p.join(imagesDir, name)).writeAsBytesSync(im.data, flush: true);
  }

  // TOC
  final tocJson = <Object?>[
    for (final t in converted.toc)
      {
        'id': t.id,
        'title': t.title,
        'href': t.href,
        'order': t.order,
      },
  ];
  File(p.join(dir, 'toc.json'))
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(tocJson)}\n',
          flush: true);

  stdout.writeln('golden_mobi: wrote ${converted.chapters.length} chapters '
      '+ ${converted.images.length} images to $dir');
}

/// 話116-120 combo 探针:章节 1 的 XHTML + recindex/图片元数据(不落整书)。
void _exportComboProbe(String outDir, Uint8List bytes) {
  final dir = p.join(outDir, 'goldens', 'mobi', 'combo');
  Directory(dir).createSync(recursive: true);

  final book = readMobi(bytes);
  final converted = convertMobiBook(book);

  File(p.join(dir, 'header.json'))
      .writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            'compression': book.header.compression,
            'textRecords': book.header.textRecords,
            'codepage': book.header.codepage,
            'version': book.header.version,
            'firstNontext': book.header.firstNontext,
            'firstResource': book.header.firstResource,
            'extraDataFlags': book.header.extraDataFlags,
            'sectionCount': book.container.sectionCount,
            'boundarySections': () {
              final found = <int>[];
              for (var i = 0; i < book.container.sectionCount; i++) {
                final s = book.container.loadSection(i);
                if (s.length >= 8 &&
                    s[0] == 0x42 && s[1] == 0x4F && s[2] == 0x55 && s[3] == 0x4E &&
                    s[4] == 0x44 && s[5] == 0x41 && s[6] == 0x52 && s[7] == 0x59) {
                  found.add(i);
                }
              }
              return found;
            }(),
          })}\n',
          flush: true);

  // recindex 槽位探针(映射 = imageForRecindex 语义)
  final probe = <String, Object?>{
    'images': [
      for (final im in book.images)
        {'index': im.index, 'mediaType': im.mediaType, 'isCover': im.isCover},
    ],
    'slotMap': {
      for (var rec = 1; rec <= book.images.last.index; rec++)
        '$rec': () {
          final im = book.imageForRecindex(rec);
          return im == null ? null : im.index;
        }(),
    },
    'chapterCount': converted.chapters.length,
    'imageHrefs': [for (final im in converted.images) im.href],
    'tocCount': converted.toc.length,
    'tocFirstTitle': converted.toc.isEmpty ? null : converted.toc.first.title,
  };
  File(p.join(dir, 'probe.json'))
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(probe)}\n',
          flush: true);

  // 章节 1(含 recindex 图引用)与 chapter href 列表
  File(p.join(dir, 'chapter0001.xhtml'))
      .writeAsStringSync(converted.chapters.first.xhtml, flush: true);
  File(p.join(dir, 'chapter_hrefs.json'))
      .writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert([for (final ch in converted.chapters) ch.href])}\n',
          flush: true);

  // 全章节 XHTML 对照(combo 大书不入 git;由工具现场导出供 Rust 对比)
  final chaptersOut = p.join(dir, 'chapters');
  Directory(chaptersOut).createSync(recursive: true);
  for (var i = 0; i < converted.chapters.length; i++) {
    File(p.join(chaptersOut, '${(i + 1).toString().padLeft(4, '0')}.xhtml'))
        .writeAsStringSync(converted.chapters[i].xhtml, flush: true);
  }
}
