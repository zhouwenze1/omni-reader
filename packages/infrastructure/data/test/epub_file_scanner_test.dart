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
  });
}
