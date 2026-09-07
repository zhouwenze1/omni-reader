import 'dart:convert';
import 'dart:io';
import 'package:reader_parser_mobi/src/mobi_reader.dart';
import 'package:test/test.dart';

void main() {
  final sample = r'C:\Users\Administrator\Desktop\Omni\.mobi-ref\samples\alice.mobi';
  if (!File(sample).existsSync()) {
    return; // 样本未下载时跳过,不阻塞 CI。
  }

  test('PalmDOC decompression + header + image extraction on Alice sample',
      () {
    final book = readMobi(File(sample).readAsBytesSync());
    expect(book.header.title, 'Alice\'s Adventures in Wonderland');
    expect(book.header.authors, <String>['Lewis Carroll']);
    expect(book.header.compression, 2); // PalmDOC

    final html = utf8.decode(book.rawHtml, allowMalformed: true);
    // kindleunpack 参考输出 ~221KB;放宽到合理区间防脆弱。
    expect(html.length, greaterThan(200000));
    expect(html.contains('Down the Rabbit-Hole'), isTrue);
    // 正文文本连贯:无大量替换符。
    final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    expect(text.contains('Alice'), isTrue);

    expect(book.images.length, greaterThanOrEqualTo(2));
    expect(book.images.first.isCover, isTrue);
    expect(book.images.first.mediaType, 'image/jpeg');
  });
}
