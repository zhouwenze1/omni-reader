import 'dart:io';
import 'package:reader_parser_mobi/reader_parser_mobi.dart';
import 'package:test/test.dart';

void main() {
  final manga = r'C:\Users\Administrator\Desktop\Omni\测试文件夹\話116-120.mobi';
  if (!File(manga).existsSync()) {
    return; // 样本未下载时跳过,不阻塞 CI。
  }

  test(
    'combo mobi: recindex maps via firstResource slot (not image ordinal)',
    () {
      final book = readMobi(File(manga).readAsBytesSync());

      // 资源区以 firstResource(0x6C)为槽 0:rec1→FONT(sec9)非图,rec2→sec10。
      final slot1 = book.imageForRecindex(1);
      final slot2 = book.imageForRecindex(2);
      expect(slot1, isNull, reason: 'rec 1 应是 FONT 槽(非图)');
      expect(slot2, isNotNull, reason: 'rec 2 应命中第一张正文图');
      expect(slot2!.index, 10, reason: '漫画 sec10 才是第 1 页图');

      // 尾页 GIF(sec138)必须可命中:rec130→sec138,而非错位到 sec139。
      final tail = book.imageForRecindex(130);
      expect(tail, isNotNull);
      expect(tail!.index, 138, reason: 'THE END 页 GIF 在 sec138');
      expect(tail.mediaType, 'image/gif');
    },
  );

  test(
    'combo mobi: cover comes from EXTH 201 (sec 139), images stop at BOUNDARY',
    () {
      final book = readMobi(File(manga).readAsBytesSync());
      final cover = book.images.where((im) => im.isCover).toList();
      expect(cover.length, 1);
      expect(
        cover.single.index,
        139,
        reason: 'EXTH 201=130 → firstResource+130',
      );
      // 后半(KF8 CRES 直存图等)不得混入。
      expect(book.images.every((im) => im.index < 145), isTrue);
    },
  );

  test(
    'combo mobi: converted chapter 1 references rec2 image, tail page intact',
    () {
      final book = readMobi(File(manga).readAsBytesSync());
      final converted = convertMobiBook(book);
      final ch1 = converted.chapters.first.xhtml;
      expect(
        ch1,
        contains('../Images/img0010.jpg'),
        reason: '第 1 頁 → rec2 → sec10',
      );
      // 图片落盘清单包含 THE END GIF(sec138)与封面(sec139)。
      final hrefs = converted.images.map((im) => im.href).toList();
      expect(hrefs, contains('Images/img0138.gif'));
      expect(hrefs, contains('Images/img0139.jpg'));
      // 目录标题带实体解码(漫画 alt)。
      final tocTitles = converted.toc.map((t) => t.title).toList();
      expect(tocTitles.first, isNotEmpty);
    },
  );
}
