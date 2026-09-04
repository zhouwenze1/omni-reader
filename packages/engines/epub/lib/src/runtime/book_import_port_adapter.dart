import 'package:foundation_domain/domain.dart';

import 'epub_import_service.dart';

/// Exposes [EpubImportService] through the domain [BookImportPort] so that
/// infrastructure code can consume EPUB imports without a direct dependency
/// on the engine package.
class EpubBookImportAdapter implements BookImportPort {
  EpubBookImportAdapter(this._importService);

  final EpubImportService _importService;

  @override
  Future<EpubImportResult> importEpubPackage({
    required String epubFilePath,
    required String bookUuid,
    EpubImportRepairMode repairMode = EpubImportRepairMode.repair,
    @Deprecated('Use repairMode instead.') bool? enableSmartTocReconciliation,
  }) async {
    final resolvedRepairMode = enableSmartTocReconciliation == null
        ? repairMode
        : enableSmartTocReconciliation
            ? EpubImportRepairMode.repair
            : EpubImportRepairMode.none;
    final package = await _importService.importEpub(
      epubFilePath: epubFilePath,
      bookUuid: bookUuid,
      repairMode: resolvedRepairMode,
    );
    return EpubImportResult(
      title: package.title,
      authors: package.authors,
      description: package.description,
      language: package.language,
      opfPath: package.opfPath,
      contentRoot: package.contentRoot,
      firstSpineHref: package.firstSpineHref,
      spineCount: package.spineItems.length,
    );
  }
}
