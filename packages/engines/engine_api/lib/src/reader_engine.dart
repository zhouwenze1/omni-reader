import 'package:foundation_domain/domain.dart';

import 'reader_session.dart';

abstract class ReaderEngine {
  String get id;

  bool supportsFormat(String format);

  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
  });
}
