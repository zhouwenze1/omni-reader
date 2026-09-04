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
  });

  final String? title;
  final List<String> authors;
  final String? description;
  final String? language;
  final String opfPath;
  final String contentRoot;
  final String? firstSpineHref;
  final int spineCount;
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
}
