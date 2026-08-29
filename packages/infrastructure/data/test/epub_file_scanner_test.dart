import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_data/data.dart';
import 'package:path/path.dart' as p;

void main() {
  group('EpubFileScanner', () {
    test('finds epub files recursively and ignores non-epub files', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'epub_file_scanner_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final nestedDir = Directory(p.join(tempRoot.path, 'A', 'B', 'C'));
      await nestedDir.create(recursive: true);

      final epub1 = File(p.join(tempRoot.path, 'root.epub'));
      final epub2 = File(p.join(nestedDir.path, 'nested.EPUB'));
      final other = File(p.join(nestedDir.path, 'ignore.txt'));

      await epub1.writeAsString('book-1', flush: true);
      await epub2.writeAsString('book-2', flush: true);
      await other.writeAsString('ignore', flush: true);

      final paths = await EpubFileScanner.collectRecursively(tempRoot.path);

      expect(paths, hasLength(2));
      expect(paths, contains(epub1.path));
      expect(paths, contains(epub2.path));
      expect(paths, isNot(contains(other.path)));
    });

    test('finds files in direct child folders but skips deeper folders',
        () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'epub_file_scanner_one_level_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final childDir = Directory(p.join(tempRoot.path, 'A'));
      final deepDir = Directory(p.join(childDir.path, 'B'));
      await deepDir.create(recursive: true);

      final rootEpub = File(p.join(tempRoot.path, 'root.epub'));
      final childEpub = File(p.join(childDir.path, 'child.EPUB'));
      final deepEpub = File(p.join(deepDir.path, 'deep.epub'));
      await rootEpub.writeAsString('root', flush: true);
      await childEpub.writeAsString('child', flush: true);
      await deepEpub.writeAsString('deep', flush: true);

      final paths = await EpubFileScanner.collectOneLevel(tempRoot.path);

      expect(paths, contains(rootEpub.path));
      expect(paths, contains(childEpub.path));
      expect(paths, isNot(contains(deepEpub.path)));
      expect(paths, hasLength(2));
    });
  });
}
