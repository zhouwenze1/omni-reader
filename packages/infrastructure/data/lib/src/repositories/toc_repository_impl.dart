import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../services/storage_paths.dart';

class TocRepositoryImpl implements TocRepository {
  TocRepositoryImpl({
    required StoragePaths storagePaths,
    required FileService fileService,
  }) : _storagePaths = storagePaths,
       _fileService = fileService;

  final StoragePaths _storagePaths;
  final FileService _fileService;

  @override
  Future<List<TocItem>> getToc(String bookUid) async {
    final filePath = p.join(
      _storagePaths.libraryRoot.path,
      bookUid,
      'toc.json',
    );
    final json = await _fileService.readJson(filePath);
    if (json == null) {
      return const [];
    }

    final list = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((it) => TocItem.fromJson(it.map((k, v) => MapEntry('$k', v))))
        .toList();
    return list;
  }

  @override
  Future<void> saveToc(String bookUid, List<TocItem> toc) {
    final filePath = p.join(
      _storagePaths.libraryRoot.path,
      bookUid,
      'toc.json',
    );
    return _fileService.writeJsonAtomic(filePath, {
      'items': toc.map((item) => item.toJson()).toList(),
    });
  }
}
