import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_data/data.dart';
import 'package:path/path.dart' as p;

void main() {
  group('TocRepositoryImpl', () {
    test('reads and flattens toc from manifest.json in books storage',
        () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'toc_repository_impl_test_',
      );
      addTearDown(() => tempRoot.delete(recursive: true));

      final storagePaths = StoragePaths.forTesting(baseDir: tempRoot);
      final fileService = FileServiceImpl();
      final repository = TocRepositoryImpl(
        storagePaths: storagePaths,
        fileService: fileService,
      );

      final bookDir = Directory(p.join(storagePaths.booksRoot.path, 'book_1'));
      await bookDir.create(recursive: true);
      await File(p.join(bookDir.path, 'manifest.json')).writeAsString(
        '''
{
  "toc": [
    {
      "title": "Part 1",
      "href": "Text/part1.xhtml",
      "children": [
        {
          "title": "Chapter 1",
          "href": "Text/ch1.xhtml"
        },
        {
          "title": "Chapter 2",
          "href": "Text/ch2.xhtml"
        }
      ]
    },
    {
      "title": "Appendix",
      "href": "Text/appendix.xhtml"
    }
  ]
}
''',
        flush: true,
      );

      final toc = await repository.getToc('book_1');

      expect(toc.map((item) => item.title), <String>[
        'Part 1',
        'Chapter 1',
        'Chapter 2',
        'Appendix',
      ]);
      expect(toc.map((item) => item.href), <String?>[
        'Text/part1.xhtml',
        'Text/ch1.xhtml',
        'Text/ch2.xhtml',
        'Text/appendix.xhtml',
      ]);
      expect(toc.map((item) => item.level), <int>[0, 1, 1, 0]);
      expect(toc.map((item) => item.parentId), <String?>[
        null,
        'toc.0',
        'toc.0',
        null,
      ]);
      expect(toc.map((item) => item.order), <int>[0, 1, 2, 3]);
      expect(toc.every((item) => item.bookUid == 'book_1'), isTrue);
    });
  });
}
