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
    return _libraryIndexDao.query(sortMode: sortMode, filters: filters);
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
    await _fileService
        .removeDir(p.join(_storagePaths.libraryRoot.path, bookUid));
    await _fileService.removeDir(p.join(_storagePaths.booksRoot.path, bookUid));
    await _libraryIndexDao.deleteByBookUid(bookUid);
  }
}
