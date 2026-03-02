import 'dart:io';

import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../db/library_index_dao.dart';
import '../services/storage_paths.dart';

class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl({
    required StoragePaths storagePaths,
    required FileService fileService,
    required LibraryIndexDao libraryIndexDao,
  })  : _storagePaths = storagePaths,
        _fileService = fileService,
        _libraryIndexDao = libraryIndexDao;

  final StoragePaths _storagePaths;
  final FileService _fileService;
  final LibraryIndexDao _libraryIndexDao;

  @override
  Future<Book?> getBook(String bookUid) async {
    final path = p.join(_storagePaths.libraryRoot.path, bookUid, 'book.json');
    final json = await _fileService.readJson(path);
    if (json == null) {
      return null;
    }
    return Book.fromJson(json);
  }

  @override
  Future<void> saveBook(Book book) async {
    final path = p.join(_storagePaths.libraryRoot.path, book.uid, 'book.json');
    await _fileService.writeJsonAtomic(path, book.toJson());
  }

  @override
  Future<List<Book>> listBooks() async {
    final dirs = await _fileService.listDirs(_storagePaths.libraryRoot.path);
    final books = <Book>[];

    for (final dirPath in dirs) {
      final baseName = p.basename(dirPath);
      if (baseName == '.tmp') {
        continue;
      }
      final file = File(p.join(dirPath, 'book.json'));
      if (!await file.exists()) {
        continue;
      }
      final json = await _fileService.readJson(file.path);
      if (json == null) {
        continue;
      }
      books.add(Book.fromJson(json));
    }

    books.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return books;
  }

  @override
  Future<List<LibraryIndexEntry>> listLibraryIndex({
    LibrarySortMode sortMode = LibrarySortMode.recentRead,
    LibraryFilters filters = const LibraryFilters(),
  }) async {
    final items = await _libraryIndexDao.listAll();
    final filtered = items.where((item) {
      if (filters.hasFormatFilter &&
          !filters.formats.map((e) => e.toLowerCase()).contains(
                item.format.toLowerCase(),
              )) {
        return false;
      }

      if (filters.hasCategoryFilter) {
        final categoryId = item.categoryId ?? '';
        if (!filters.categoryIds.contains(categoryId)) {
          return false;
        }
      }

      final progress = item.cachedProgress ?? 0.0;
      switch (filters.progress) {
        case LibraryProgressBucket.all:
          return true;
        case LibraryProgressBucket.notStarted:
          return progress <= 0.0001;
        case LibraryProgressBucket.inProgress:
          return progress > 0.0001 && progress < 0.9999;
        case LibraryProgressBucket.completed:
          return progress >= 0.9999;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (sortMode) {
        case LibrarySortMode.recentRead:
          final aTime = a.lastOpenedAt ?? a.updatedAt;
          final bTime = b.lastOpenedAt ?? b.updatedAt;
          return bTime.compareTo(aTime);
        case LibrarySortMode.importedAt:
          return b.importedAt.compareTo(a.importedAt);
        case LibrarySortMode.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    return filtered;
  }

  @override
  Future<LibraryIndexEntry?> findLibraryIndexByFingerprint(String fingerprint) {
    return _libraryIndexDao.findByFingerprint(fingerprint);
  }

  @override
  Future<void> upsertLibraryIndex(LibraryIndexEntry entry) {
    return _libraryIndexDao.upsert(entry);
  }

  @override
  Future<void> deleteBook(String bookUid) async {
    await _fileService.removeDir(p.join(_storagePaths.libraryRoot.path, bookUid));
    await _fileService.removeDir(p.join(_storagePaths.booksRoot.path, bookUid));
    await _libraryIndexDao.deleteByBookUid(bookUid);
  }
}
