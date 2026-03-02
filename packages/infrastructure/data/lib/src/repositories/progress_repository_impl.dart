import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../db/library_index_dao.dart';
import '../services/storage_paths.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl({
    required StoragePaths storagePaths,
    required FileService fileService,
    required LibraryIndexDao libraryIndexDao,
  }) : _storagePaths = storagePaths,
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
    );
  }
}
