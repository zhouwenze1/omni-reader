import 'package:foundation_domain/domain.dart';

import 'epub_import_service.dart';
import 'mobi_import_service.dart';

/// Exposes [EpubImportService] (+ [MobiImportService]) through the domain
/// [BookImportPort] so that infrastructure code can consume imports without a
/// direct dependency on the engine package.
class EpubBookImportAdapter implements BookImportPort {
  EpubBookImportAdapter(this._importService, {required MobiImportService mobiImporter})
      : _mobiImporter = mobiImporter;

  final EpubImportService _importService;
  final MobiImportService _mobiImporter;

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

  @override
  Future<EpubImportResult> importMobiPackage({
    required String mobiFilePath,
    required String bookUuid,
  }) async {
    final result = await _mobiImporter.importMobi(
      mobiFilePath: mobiFilePath,
      bookUuid: bookUuid,
    );
    return EpubImportResult(
      title: result.title,
      authors: result.authors,
      description: null,
      language: result.language,
      opfPath: '',
      contentRoot: MobiImportService.contentRoot,
      firstSpineHref: result.firstSpineHref,
      spineCount: 0,
      coverBytes: result.coverImage?.data,
      coverMediaType: result.coverImage?.mediaType,
    );
  }
}
