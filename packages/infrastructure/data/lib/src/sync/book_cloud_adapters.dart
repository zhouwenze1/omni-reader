import 'dart:io';

import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;
import 'package:services_sync/services_sync.dart';

import '../db/library_index_dao.dart';
import '../services/storage_paths.dart';

/// 书架索引端口实现:直接操作 LibraryIndexDao。
class BookCloudLibraryAdapter implements BookCloudLibraryPort {
  BookCloudLibraryAdapter(this._dao);

  final LibraryIndexDao _dao;

  @override
  Future<LibraryIndexEntry?> findByBookUid(String bookUid) {
    return _dao.findByBookUid(bookUid);
  }

  @override
  Future<List<LibraryIndexEntry>> listAllEntries() {
    return _dao.listAll();
  }

  @override
  Future<void> upsertEntry(LibraryIndexEntry entry) {
    return _dao.upsert(entry);
  }

  @override
  Future<void> setCloudStatus(String bookUid, CloudBackupStatus status) {
    return _dao.setCloudStatus(bookUid, status);
  }

  @override
  Future<void> setEvicted(String bookUid, {required bool evicted}) {
    return _dao.setEvicted(bookUid, evicted: evicted);
  }

  @override
  Future<void> setPinLocal(String bookUid, {required bool pinned}) {
    return _dao.setPinLocal(bookUid, pinned: pinned);
  }

  @override
  Future<void> deleteIndexEntry(String bookUid) {
    return _dao.deleteByBookUid(bookUid);
  }
}

/// 书文件端口实现:书库目录上的大文件操作 + 走 ImportRepository 取回。
class BookCloudFilesAdapter implements BookCloudFilesPort {
  BookCloudFilesAdapter({
    required StoragePaths storagePaths,
    required BookStoragePort bookStoragePort,
    required ImportRepository importRepository,
  })  : _storagePaths = storagePaths,
        _bookStoragePort = bookStoragePort,
        _importRepository = importRepository;

  final StoragePaths _storagePaths;
  final BookStoragePort _bookStoragePort;
  final ImportRepository _importRepository;

  String get _libraryRoot => _storagePaths.libraryRoot.path;

  @override
  Future<File?> originalFile(String bookUid) async {
    final dir = Directory(p.join(_libraryRoot, bookUid, 'original'));
    if (!dir.existsSync()) return null;
    for (final entity in dir.listSync()) {
      if (entity is File) return entity;
    }
    return null;
  }

  @override
  Future<File?> coverFile(String bookUid) async {
    final dir = Directory(p.join(_libraryRoot, bookUid));
    if (!dir.existsSync()) return null;
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last.toLowerCase();
        if (name.startsWith('cover.')) return entity;
      }
    }
    return null;
  }

  @override
  Future<void> saveCoverBytes(String bookUid, List<int> bytes, String ext) async {
    final dir = Directory(p.join(_libraryRoot, bookUid));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'cover.$ext'));
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> evictBookFiles(String bookUid) async {
    // 解析产物目录(booksRoot/<uid>)。
    final booksDir = Directory(_bookStoragePort.bookDirPath(bookUid));
    if (booksDir.existsSync()) {
      booksDir.deleteSync(recursive: true);
    }
    // 原始文件目录(library/<uid>/original),保留 book.json/进度/标注/封面。
    final originalDir = Directory(p.join(_libraryRoot, bookUid, 'original'));
    if (originalDir.existsSync()) {
      originalDir.deleteSync(recursive: true);
    }
  }

  @override
  Future<bool> hasLocalArtifacts(String bookUid) async {
    final metaFile = File(p.join(_bookStoragePort.bookDirPath(bookUid), 'meta.json'));
    return metaFile.existsSync();
  }

  @override
  Future<String> createTempOriginalFile(String bookUid, String ext) async {
    final dir = Directory(
      p.join(_storagePaths.tempRoot.path, 'cloud-restore', bookUid),
    );
    await dir.create(recursive: true);
    return p.join(dir.path, 'original.$ext');
  }

  @override
  Future<void> restoreFromOriginal({
    required String bookUid,
    required String originalPath,
  }) async {
    final result = await _importRepository.restoreBookFromOriginalFile(
      bookUid: bookUid,
      filePath: originalPath,
    );
    if (result.task.status != ImportTaskStatus.success) {
      throw StateError(result.task.errorMessage ?? 'restore failed');
    }
  }
}
