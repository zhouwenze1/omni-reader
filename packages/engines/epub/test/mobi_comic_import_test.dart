import 'dart:convert';
import 'dart:io';
import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = r'C:\Users\Administrator\Desktop\Omni\测试文件夹\話116-120.mobi';
  if (!File(sample).existsSync()) return;

  test('comic-style mobi: images resolve, page titles, no empty chapters',
      () async {
    final root = await Directory.systemTemp.createTemp('mobi_comic');
    addTearDown(() => root.delete(recursive: true));
    final storage = BookStorageService(booksRootPath: root.path);
    final svc = MobiImportService(storageService: storage);
    await svc.importMobi(
      mobiFilePath: sample,
      bookUuid: 'comicuid00000000000000000000000000',
    );
    final bookDir = '${root.path}/comicuid00000000000000000000000000';
    // 章节图片引用相对 Text/ → ../Images/
    final ch1 =
        File('$bookDir/raw/OEBPS/Text/chapter0001.xhtml').readAsStringSync();
    expect(ch1, contains('../Images/'));
    expect(ch1, isNot(contains('src="Images/'))); // 不能缺 ..
    // recindex 走 firstResource 槽:第 1 章(rec2)必须指到 sec10 的图,而非错位。
    expect(ch1, contains('../Images/img0010.jpg'));
    expect(ch1, isNot(contains('../Images/img0011.jpg')));
    // 目录有页码标题(漫画是 img alt),非 "Chapter N" 占位
    final meta = jsonDecode(File('$bookDir/meta.json').readAsStringSync())
        as Map<String, dynamic>;
    final toc = meta['toc'] as List;
    expect(toc.length, greaterThan(100)); // 129 页左右
    final firstTitle = ((toc.first as Map)['title'] as String);
    expect(firstTitle, isNot(startsWith('Chapter ')));
    // 图片文件确实落盘,且含尾页 GIF(sec138)与封面(sec139)。
    final imgDir = Directory('$bookDir/raw/OEBPS/Images');
    final imgNames =
        imgDir.listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(imgNames.length, greaterThan(100));
    expect(imgNames, contains('img0138.gif')); // THE END 页
    expect(imgNames, contains('img0139.jpg')); // 封面(EXTH 201)
  });
}
