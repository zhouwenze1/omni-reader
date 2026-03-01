import 'dart:typed_data';

import 'package:epub_pro/epub_pro.dart';

import '../models.dart';

class EpubTextExtractor implements ChapterTextSource {
  const EpubTextExtractor();

  @override
  Future<List<ChapterText>> readChapters(Uint8List epubBytes) async {
    final bookRef = await EpubReader.openBook(epubBytes);
    final spineMap = bookRef.getSpineChapterMap();
    final spineEntries = spineMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final chapters = <ChapterText>[];
    for (final entry in spineEntries) {
      final spineIndex = entry.key;
      final chapterRef = entry.value;
      final html = await chapterRef.readHtmlContent();
      chapters.add(
        ChapterText(
          spineIndex: spineIndex,
          href: chapterRef.contentFileName,
          cfi: bookRef.createProgressCFI(spineIndex).toString(),
          text: html,
        ),
      );
    }
    return chapters;
  }
}
