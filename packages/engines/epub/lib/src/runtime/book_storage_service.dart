import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'book_package.dart';

class BookStorageService {
  BookStorageService({required String booksRootPath})
      : _booksRoot = Directory(booksRootPath);

  final Directory _booksRoot;

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
}
