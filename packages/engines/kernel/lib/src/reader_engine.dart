import 'package:foundation_domain/domain.dart';

import 'reader_capability.dart';
import 'reader_session.dart';
import 'reader_style.dart';

abstract class ReaderEngine {
  String get id;

  String get displayName => id.toUpperCase();

  Set<String> get supportedFormats;

  Set<ReaderCapability> get capabilities;

  bool supportsFormat(String format) {
    final normalized = format.trim().toLowerCase();
    return supportedFormats.contains(normalized);
  }

  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
    ReaderStyle initialStyle = ReaderStyle.defaults,
  });
}
