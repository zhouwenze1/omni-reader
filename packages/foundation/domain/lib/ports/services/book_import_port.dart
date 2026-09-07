import '../../models/import_models.dart';

/// Domain-facing snapshot of an imported EPUB package.
///
/// Deliberately decoupled from engine and parser package types so that
/// infrastructure code can consume import results without depending on the
/// EPUB engine directly.
class EpubImportResult {
  const EpubImportResult({
    required this.title,
    required this.authors,
    required this.description,
    required this.language,
    required this.opfPath,
    required this.contentRoot,
    required this.firstSpineHref,
    required this.spineCount,
    this.coverBytes,
    this.coverMediaType,
  });

  final String? title;
  final List<String> authors;
  final String? description;
  final String? language;
  final String opfPath;
  final String contentRoot;
  final String? firstSpineHref;
  final int spineCount;

  /// 反解出的封面字节(仅 mobi/webpub 导入时非空),供落盘封面用。
  final List<int>? coverBytes;
  final String? coverMediaType;
}

abstract class BookImportPort {
  /// Parses [epubFilePath], generates and persists the EPUB derivative
  /// artifacts under the book identified by [bookUuid], and returns the
  /// domain-facing import result.
  Future<EpubImportResult> importEpubPackage({
    required String epubFilePath,
    required String bookUuid,
    EpubImportRepairMode repairMode = EpubImportRepairMode.repair,
    @Deprecated('Use repairMode instead.') bool? enableSmartTocReconciliation,
  });

  /// 反解 [mobiFilePath](.mobi/.azw3),把清洗分章产物落成 raw 目录 + meta.json
  /// (EPUB 引擎可直接读的形态),返回领域层结果。book.format 由调用方记为
  /// 'webpub',路由进 epub 引擎。
  Future<EpubImportResult> importMobiPackage({
    required String mobiFilePath,
    required String bookUuid,
  });
}
