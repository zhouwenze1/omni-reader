import 'dart:io';

import 'package:services_search/services_search.dart';

const kEpubPath =
    r'C:\Users\Administrator\Desktop\reader\packages\infrastructure\services_search\example\test.epub';
const kQuery = '男女';
const kBookId = 'manual11-book';

Future<void> main() async {
  final file = File(kEpubPath);
  if (!await file.exists()) {
    stderr.writeln('EPUB file not found: $kEpubPath');
    exitCode = 2;
    return;
  }

  final bytes = await file.readAsBytes();
  final service = EpubSearchService(index: MemorySearchIndex());
  final hits = await service.search(
    SearchQuery(
      bookId: kBookId,
      query: kQuery,
      limit: 30,
      contextChars: 40,
    ),
    epubBytes: bytes,
    includeParagraphText: false,
  );

  stdout.writeln('Hits: ${hits.length}');
  for (final hit in hits) {
    stdout.writeln(
      '[spine=${hit.spineIndex} para=${hit.paraIndex}] '
      'href=${hit.href} cfi=${hit.cfi} snippet=${hit.snippet}',
    );
  }
}
