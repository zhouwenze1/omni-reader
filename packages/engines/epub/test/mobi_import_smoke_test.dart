import 'dart:io';
import 'package:engine_epub/engine_epub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = r'C:\Users\Administrator\Desktop\Omni\.mobi-ref\samples\alice.mobi';
  if (!File(sample).existsSync()) {
    return; // 样本缺失时跳过。
  }

  test('MobiImportService writes raw chapters + meta.json', () async {
    final root = await Directory.systemTemp.createTemp('mobi_smoke');
    addTearDown(() => root.delete(recursive: true));
    final storage = BookStorageService(booksRootPath: root.path);
    final svc = MobiImportService(storageService: storage);
    final result = await svc.importMobi(
      mobiFilePath: sample,
      bookUuid: 'smokeuid1234567890abcdef',
    );
    expect(result.title, "Alice's Adventures in Wonderland");
    expect(result.authors, <String>['Lewis Carroll']);
    expect(result.firstSpineHref, 'Text/chapter0001.xhtml');
    expect(result.coverImage?.mediaType, 'image/jpeg');

    final bookDir = Directory('${root.path}/smokeuid1234567890abcdef');
    final rawDir = Directory('${bookDir.path}/raw/OEBPS');
    expect(rawDir.existsSync(), isTrue);
    final files = rawDir.listSync(recursive: true).whereType<File>().toList();
    final chapters = files.where((f) => f.path.endsWith('.xhtml')).toList();
    expect(chapters.length, greaterThanOrEqualTo(5));
    final meta = File('${bookDir.path}/meta.json');
    expect(meta.existsSync(), isTrue);
    final metaText = meta.readAsStringSync();
    expect(metaText, contains('Text/chapter0001.xhtml'));
    expect(metaText, contains('Alice'));
  });
}
