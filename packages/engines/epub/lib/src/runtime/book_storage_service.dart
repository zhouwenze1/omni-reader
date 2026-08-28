import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import 'book_package.dart';

class BookStorageService implements BookStoragePort {
  BookStorageService({required String booksRootPath})
      : _booksRoot = Directory(booksRootPath);

  final Directory _booksRoot;

  String get booksRootPath => _booksRoot.path;

  @override
  String bookDirPath(String bookUuid) {
    return p.join(_booksRoot.path, bookUuid);
  }

  String rawDirPath(String bookUuid) {
    return p.join(bookDirPath(bookUuid), 'raw');
  }

  String archiveFilePath(String bookUuid) {
    return p.join(bookDirPath(bookUuid), 'book.epub');
  }

  String metaFilePath(String bookUuid) {
    return p.join(bookDirPath(bookUuid), 'meta.json');
  }

  String artifactFilePath(String bookUuid, String fileName) {
    return p.join(bookDirPath(bookUuid), fileName);
  }

  String manifestFilePath(String bookUuid) {
    return artifactFilePath(bookUuid, 'manifest.json');
  }

  String positionsFilePath(String bookUuid) {
    return artifactFilePath(bookUuid, 'positions.json');
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
  }

  @override
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

  Future<void> saveArchive(
    String bookUuid, {
    required String sourceFilePath,
  }) async {
    await prepareBookDirs(bookUuid);

    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw StateError('EPUB archive not found: $sourceFilePath');
    }

    final targetPath = archiveFilePath(bookUuid);
    final targetFile = File(targetPath);
    final parent = targetFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await sourceFile.copy(targetPath);
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

  Future<void> saveArtifactFileMap(
    String bookUuid,
    Map<String, Map<String, Object?>> files,
  ) async {
    await prepareBookDirs(bookUuid);
    for (final entry in files.entries) {
      final json = entry.value.map((key, value) => MapEntry(key, value));
      await _writeJsonAtomic(artifactFilePath(bookUuid, entry.key), json);
    }
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

  Future<Map<String, dynamic>?> readLastLocator(String bookUuid) async {
    final metadata = await readMetadata(bookUuid);
    return metadata?.lastLocator;
  }

  Future<Map<String, dynamic>?> readArtifactJson(
    String bookUuid,
    String fileName,
  ) async {
    final file = File(artifactFilePath(bookUuid, fileName));
    if (!await file.exists()) {
      return null;
    }
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  Future<Map<String, dynamic>?> readPositionsDocument(String bookUuid) {
    return readArtifactJson(bookUuid, 'positions.json');
  }

  Future<void> deleteArtifactIfExists(String bookUuid, String fileName) async {
    final file = File(artifactFilePath(bookUuid, fileName));
    if (await file.exists()) {
      await file.delete();
    }
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
