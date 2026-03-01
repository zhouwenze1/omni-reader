import 'dart:io';

import 'package:services_search/services_search.dart';
import 'package:test/test.dart';

const kEpubPath = r'D:\books\your_book.epub';
const kQuery = 'keyword';
const kBookId = 'manual-epub-book';

void main() {
  final shouldSkip = kEpubPath.trim().isEmpty || !File(kEpubPath).existsSync();

  test(
    'searches a real EPUB from hardcoded absolute path',
    () async {
      final file = File(kEpubPath);
      expect(await file.exists(), isTrue,
          reason: 'EPUB file does not exist: $kEpubPath');

      final service = EpubSearchService(index: MemorySearchIndex());
      final hits = await service.search(
        SearchQuery(
          bookId: kBookId,
          query: kQuery,
          limit: 20,
          contextChars: 40,
        ),
        epubBytes: await file.readAsBytes(),
      );

      expect(hits, isNotEmpty, reason: 'No search hits for query "$kQuery".');

      for (final hit in hits.take(5)) {
        // This helps manual verification when running the test locally.
        print(
          '[spine=${hit.spineIndex} para=${hit.paraIndex}] '
          'href=${hit.href} cfi=${hit.cfi} snippet=${hit.snippet}',
        );
      }
    },
    skip: shouldSkip
        ? 'Set kEpubPath to an existing absolute path in this file.'
        : false,
  );
}
