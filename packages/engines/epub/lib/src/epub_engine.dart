import 'package:kernel/kernel.dart';
import 'package:foundation_domain/domain.dart';

import 'epub_session.dart';

class EpubReaderEngine extends ReaderEngine {
  static const Set<String> _formats = <String>{'epub', 'webpub'};

  static const Set<ReaderCapability> _capabilities = <ReaderCapability>{
    ReaderCapability.linearNavigation,
    ReaderCapability.jumpNavigation,
    ReaderCapability.style,
    ReaderCapability.theme,
    ReaderCapability.externalLink,
    ReaderCapability.mediaTap,
    ReaderCapability.selection,
    ReaderCapability.highlights,
    ReaderCapability.toc,
    ReaderCapability.inBookSearch,
  };

  @override
  String get id => 'epub';

  @override
  String get displayName => 'EPUB';

  @override
  Set<String> get supportedFormats => _formats;

  @override
  Set<ReaderCapability> get capabilities => _capabilities;

  @override
  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
    ReaderStyle initialStyle = ReaderStyle.defaults,
  }) async {
    return EpubReaderSession(
      book: book,
      initialProgress: initialProgress,
      initialStyle: initialStyle,
    );
  }
}
