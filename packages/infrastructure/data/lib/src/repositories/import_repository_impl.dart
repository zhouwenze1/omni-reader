import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:engine_epub/engine_epub.dart';
import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../services/storage_paths.dart';
import '../services/cover_extraction_service.dart';

class ImportRepositoryImpl implements ImportRepository {
  ImportRepositoryImpl({
    required StoragePaths storagePaths,
    required FileService fileService,
    required FingerprintService fingerprintService,
    required BookRepository bookRepository,
    required ProgressRepository progressRepository,
    required PdfPackager pdfPackager,
    required LpfToAudiobookConverter audiobookConverter,
    required EpubImportService epubImportService,
    required BookStorageService bookStorageService,
    required CoverExtractionService coverExtractionService,
  })  : _storagePaths = storagePaths,
        _fileService = fileService,
        _fingerprintService = fingerprintService,
        _bookRepository = bookRepository,
        _progressRepository = progressRepository,
        _pdfPackager = pdfPackager,
        _audiobookConverter = audiobookConverter,
        _epubImportService = epubImportService,
        _bookStorageService = bookStorageService,
        _coverExtractionService = coverExtractionService;

  final StoragePaths _storagePaths;
  final FileService _fileService;
  final FingerprintService _fingerprintService;
  final BookRepository _bookRepository;
  final ProgressRepository _progressRepository;
  final PdfPackager _pdfPackager;
  final LpfToAudiobookConverter _audiobookConverter;
  final EpubImportService _epubImportService;
  final BookStorageService _bookStorageService;
  final CoverExtractionService _coverExtractionService;

  @override
  Future<ImportResult> importBookFromFile(
    String filePath, {
    bool debugMode = false,
    ImportBookOptions options = const ImportBookOptions(),
  }) async {
    final startedAt = DateTime.now();
    final taskId = sha256
        .convert(utf8.encode('$filePath-${startedAt.microsecondsSinceEpoch}'))
        .toString()
        .substring(0, 16);

    ImportTask task = ImportTask(
      id: taskId,
      filePath: filePath,
      status: ImportTaskStatus.pending,
      startedAt: startedAt,
    );

    String? tmpDir;
    String? importingBookUid;
    bool importedEpubPackage = false;
    final cleanCallbacks = <Future<void> Function()>[];

    try {
      final sourceFile = File(filePath);
      final originalName = p.basename(filePath);
      final format = _detectFormat(filePath);

      final fingerprint = format == 'pdf'
          ? await _fingerprintService.hashPdfFile(filePath)
          : await _fingerprintService.zipFingerprint(filePath);

      final existed = await _bookRepository.findLibraryIndexByFingerprint(
        fingerprint,
      );
      if (existed != null) {
        task = task.copyWith(
          status: ImportTaskStatus.alreadyImported,
          bookUid: existed.bookUid,
          finishedAt: DateTime.now(),
        );
        return ImportResult(
          alreadyImported: true,
          bookUid: existed.bookUid,
          task: task,
        );
      }

      final bookUid = _deriveBookUid(fingerprint);
      importingBookUid = bookUid;
      final finalBookDir = p.join(_storagePaths.libraryRoot.path, bookUid);
      tmpDir = p.join(_storagePaths.libraryRoot.path, '.tmp', bookUid);
      await _fileService.ensureDir(tmpDir);
      await _fileService.ensureDir(p.join(tmpDir, 'original'));

      String? tempConvertedPath;
      BookPackage? epubPackage;

      if (format == 'epub') {
        epubPackage = await _epubImportService.importEpub(
          epubFilePath: filePath,
          bookUuid: bookUid,
          enableSmartTocReconciliation: options.enableSmartTocReconciliation,
        );
        importedEpubPackage = true;
      }

      if (format == 'w3cAudiobook') {
        final conversion = await _audiobookConverter.convert(
          filePath,
          _storagePaths.tempRoot.path,
        );
        tempConvertedPath = conversion.outputPath;
        if (conversion.clean != null) {
          cleanCallbacks.add(conversion.clean!);
        }
      } else if (format == 'pdf') {
        final conversion = await _pdfPackager.packagePdf(
          filePath,
          _storagePaths.tempRoot.path,
        );
        tempConvertedPath = conversion.outputPath;
        if (conversion.clean != null) {
          cleanCallbacks.add(conversion.clean!);
        }
      }

      final originalRelPath =
          p.join('original', originalName).replaceAll('\\', '/');
      final originalTarget = p.join(tmpDir, originalRelPath);
      await _fileService.copyFile(filePath, originalTarget);

      final now = DateTime.now();
      String? coverRelPath;
      if (format == 'epub' && epubPackage != null) {
        coverRelPath =
            await _coverExtractionService.extractEpubCoverToLibraryTemp(
          bookUid: bookUid,
          opfPath: epubPackage.opfPath,
          tempBookDir: tmpDir,
        );
      }

      final book = Book(
        uid: bookUid,
        format: format,
        title: format == 'epub'
            ? _preferredText(
                epubPackage?.title,
                p.basenameWithoutExtension(originalName),
              )!
            : p.basenameWithoutExtension(originalName),
        authors: format == 'epub'
            ? List<String>.from(epubPackage?.authors ?? const <String>[])
            : const <String>[],
        description: format == 'epub'
            ? _preferredText(epubPackage?.description, null)
            : null,
        language: format == 'epub'
            ? _preferredText(epubPackage?.language, null)
            : null,
        rootDir: format == 'epub'
            ? _bookStorageService.bookDirPath(bookUid)
            : finalBookDir,
        originalRelPath: originalRelPath,
        coverRelPath: coverRelPath,
        tags: const [],
        categoryId: null,
        status: BookStatus.ready,
        importedAt: now,
        updatedAt: now,
        lastOpenedAt: null,
        sizeBytes: await sourceFile.length(),
        fileHash: fingerprint,
      );

      final initialLocator = format == 'epub'
          ? Locator(
              href: epubPackage?.firstSpineHref,
              cfi: null,
              locations: const {'progression': 0.0},
              anchor: null,
              text: null,
              extras: null,
            )
          : const Locator(
              locations: {'progression': 0.0},
              extras: {'source': 'import-init'},
            );

      final progress = ReadingProgress(
        bookUid: bookUid,
        locator: initialLocator,
        progression: 0,
        updatedAt: now,
        lastReadAt: null,
      );

      await _fileService.writeJsonAtomic(
        p.join(tmpDir, 'book.json'),
        book.toJson(),
      );
      await _fileService.writeJsonAtomic(
        p.join(tmpDir, 'progress.json'),
        progress.toJson(),
      );

      if (debugMode) {
        await _fileService.writeJsonAtomic(
          p.join(_storagePaths.cacheRoot.path, 'debug-import.json'),
          {
            'timestamp': now.toIso8601String(),
            'originalName': originalName,
            'detectedFormat': format,
            'fingerprint': fingerprint,
            'tempConvertedPath': tempConvertedPath,
            'epubOpfPath': epubPackage?.opfPath,
            'epubContentRoot': epubPackage?.contentRoot,
            'epubSpineCount': epubPackage?.spineItems.length,
            'epubTitle': epubPackage?.title,
            'epubAuthors': epubPackage?.authors,
            'epubSmartTocReconciliation': options.enableSmartTocReconciliation,
          },
        );
      }

      await _fileService.moveDirAtomic(tmpDir, finalBookDir);

      await _bookRepository.upsertLibraryIndex(
        LibraryIndexEntry(
          bookUid: bookUid,
          fingerprint: fingerprint,
          format: format,
          title: book.title,
          authors: book.authors,
          categoryId: book.categoryId,
          coverRelPath: book.coverRelPath,
          importedAt: book.importedAt,
          updatedAt: book.updatedAt,
          lastOpenedAt: null,
          cachedProgress: 0,
        ),
      );

      await _progressRepository.saveProgress(progress);

      task = task.copyWith(
        status: ImportTaskStatus.success,
        bookUid: bookUid,
        finishedAt: DateTime.now(),
      );

      return ImportResult(alreadyImported: false, bookUid: bookUid, task: task);
    } catch (error) {
      if (tmpDir != null) {
        await _fileService.removeDir(tmpDir);
      }
      if (importedEpubPackage && importingBookUid != null) {
        await _bookStorageService.clearBook(importingBookUid);
      }

      task = task.copyWith(
        status: ImportTaskStatus.failed,
        errorMessage: error.toString(),
        finishedAt: DateTime.now(),
      );

      return ImportResult(alreadyImported: false, bookUid: null, task: task);
    } finally {
      for (final clean in cleanCallbacks) {
        await clean();
      }
    }
  }

  String _detectFormat(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'pdf';
    }
    if (lower.endsWith('.epub')) {
      return 'epub';
    }
    if (lower.endsWith('.ldf')) {
      return 'ldf';
    }
    if (lower.endsWith('.lpf')) {
      return 'w3cAudiobook';
    }
    if (lower.endsWith('.webpub')) {
      return 'webpub';
    }
    if (lower.endsWith('.zip') || lower.endsWith('.cbz')) {
      return 'comicZip';
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.m4b')) {
      return 'audio';
    }
    return 'unknown';
  }

  String _deriveBookUid(String hash) {
    final digest = sha256.convert(utf8.encode(hash)).toString();
    return digest.substring(0, 32);
  }

  String? _preferredText(String? primary, String? fallback) {
    final first = primary?.trim();
    if (first != null && first.isNotEmpty) {
      return first;
    }
    final second = fallback?.trim();
    if (second != null && second.isNotEmpty) {
      return second;
    }
    return null;
  }
}
