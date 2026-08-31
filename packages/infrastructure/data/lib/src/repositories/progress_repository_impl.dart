import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../db/library_index_dao.dart';
import '../services/storage_paths.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl({
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
  Future<ReadingProgress?> getProgress(String bookUid) async {
    final path = p.join(
      _storagePaths.libraryRoot.path,
      bookUid,
      'progress.json',
    );
    final json = await _fileService.readJson(path);
    if (json == null) {
      return null;
    }
    return ReadingProgress.fromJson(json);
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    final path = p.join(
      _storagePaths.libraryRoot.path,
      progress.bookUid,
      'progress.json',
    );

    await _fileService.writeJsonAtomic(path, progress.toJson());
    await _libraryIndexDao.updateCachedProgress(
      progress.bookUid,
      progress.progression,
      updatedAt: progress.updatedAt,
      lastOpenedAt: progress.lastReadAt,
    );
  }

  @override
  Future<List<ReadingProgress>> listProgress() async {
    final libraryRoot = _storagePaths.libraryRoot.path;
    final bookDirs = await _fileService.listDirs(libraryRoot);
    final result = <ReadingProgress>[];
    for (final bookUid in bookDirs) {
      final json = await _fileService.readJson(
        p.join(libraryRoot, bookUid, 'progress.json'),
      );
      if (json != null) {
        try {
          result.add(ReadingProgress.fromJson(json));
        } catch (_) {
          // 进度文件损坏时跳过,不阻塞同步。
        }
      }
    }
    return result;
  }
}
