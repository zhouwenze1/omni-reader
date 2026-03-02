import 'package:engine_api/engine_api.dart';
import 'package:foundation_domain/domain.dart';

import 'epub_session.dart';

class EpubReaderEngine implements ReaderEngine {
  @override
  String get id => 'epub';

  @override
  bool supportsFormat(String format) {
    return format.toLowerCase() == 'epub' || format.toLowerCase() == 'webpub';
  }

  @override
  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
  }) async {
    return EpubReaderSession(book: book, initialProgress: initialProgress);
  }
}
