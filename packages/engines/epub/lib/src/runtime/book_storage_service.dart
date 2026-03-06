import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'book_package.dart';

class BookStorageService {
  BookStorageService({required String booksRootPath})
      : _booksRoot = Directory(booksRootPath);

  static const Duration _locatorDebounceWindow = Duration(milliseconds: 420);

  final Directory _booksRoot;
  final Map<String, Map<String, dynamic>> _pendingLastLocators =
      <String, Map<String, dynamic>>{};
  final Map<String, Timer> _lastLocatorTimers = <String, Timer>{};
  final Map<String, Future<void>> _lastLocatorWriteChains =
      <String, Future<void>>{};

  String get booksRootPath => _booksRoot.path;

  String bookDirPath(String bookUuid) {
    return p.join(_booksRoot.path, bookUuid);
  }

  String rawDirPath(String bookUuid) {
    return p.join(bookDirPath(bookUuid), 'raw');
  }

  String metaFilePath(String bookUuid) {
    return p.join(bookDirPath(bookUuid), 'meta.json');
  }

  Future<void> ensureBooksRoot() async {
    if (!await _booksRoot.exists()) {
      await _booksRoot.create(recursive: true);
    }
  }

  Future<void> prepareBookDirs(String bookUuid) async {
    await ensureBooksRoot();
    final bookDir = Directory(bookDirPath(bookUuid));
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    final rawDir = Directory(rawDirPath(bookUuid));
    if (!await rawDir.exists()) {
      await rawDir.create(recursive: true);
    }
  }

  Future<void> clearBook(String bookUuid) async {
    final dir = Directory(bookDirPath(bookUuid));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> clearRaw(String bookUuid) async {
    final dir = Directory(rawDirPath(bookUuid));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }

  Future<void> savePackage(BookPackage package) async {
    await prepareBookDirs(package.bookUuid);
    final existing = await readMetadata(package.bookUuid);
    final metadata = package.toMetadata(
      lastLocator: existing?.lastLocator,
      updatedAt: DateTime.now(),
    );
    await _writeJsonAtomic(metaFilePath(package.bookUuid), metadata.toJson());
  }

  Future<BookPackageMetadata?> readMetadata(String bookUuid) async {
    final file = File(metaFilePath(bookUuid));
    if (!await file.exists()) {
      return null;
    }
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return BookPackageMetadata.fromJson(decoded);
    }
    if (decoded is Map) {
      return BookPackageMetadata.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
    }
    return null;
  }

  Future<void> saveLastLocator(
    String bookUuid,
    Map<String, dynamic> locator,
  ) async {
    _pendingLastLocators[bookUuid] = Map<String, dynamic>.from(locator);
    _lastLocatorTimers[bookUuid]?.cancel();
    _lastLocatorTimers[bookUuid] = Timer(_locatorDebounceWindow, () {
      unawaited(_flushLastLocator(bookUuid));
    });
  }

  Future<void> flushPendingLocator(String bookUuid) {
    return _flushLastLocator(bookUuid);
  }

  Future<Map<String, dynamic>?> readLastLocator(String bookUuid) async {
    final metadata = await readMetadata(bookUuid);
    return metadata?.lastLocator;
  }

  Future<void> _writeJsonAtomic(String filePath, Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return _writeTextAtomic(filePath, encoder.convert(json));
  }

  Future<void> _writeTextAtomic(String filePath, String content) async {
    final parent = Directory(p.dirname(filePath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final tempPath =
        '$filePath.__tmp__${DateTime.now().microsecondsSinceEpoch}';
    final tempFile = File(tempPath);
    await tempFile.writeAsString(content, flush: true);

    final targetFile = File(filePath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(filePath);
  }

  Future<void> _flushLastLocator(String bookUuid) async {
    _lastLocatorTimers.remove(bookUuid)?.cancel();
    final pending = _pendingLastLocators.remove(bookUuid);
    if (pending == null || pending.isEmpty) {
      return;
    }

    final previous = _lastLocatorWriteChains[bookUuid] ?? Future<void>.value();
    final next = previous.then((_) => _persistLastLocator(bookUuid, pending));
    _lastLocatorWriteChains[bookUuid] = next.catchError((_) {});

    try {
      await next;
    } finally {
      if (identical(_lastLocatorWriteChains[bookUuid], next)) {
        _lastLocatorWriteChains.remove(bookUuid);
      }
    }
  }

  Future<void> _persistLastLocator(
    String bookUuid,
    Map<String, dynamic> locator,
  ) async {
    final existing = await readMetadata(bookUuid);
    if (existing == null) {
      return;
    }
    final next = existing.copyWith(
      lastLocator: locator,
      updatedAt: DateTime.now(),
    );
    await _writeJsonAtomic(metaFilePath(bookUuid), next.toJson());
  }
}
