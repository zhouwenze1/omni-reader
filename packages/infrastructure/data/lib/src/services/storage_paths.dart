import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoragePaths {
  StoragePaths._({
    required this.baseDir,
    required this.cacheRoot,
    required this.tempRoot,
  });

  factory StoragePaths.forTesting({
    required Directory baseDir,
    Directory? cacheRoot,
    Directory? tempRoot,
  }) {
    final resolvedCacheRoot =
        cacheRoot ?? Directory(p.join(baseDir.path, '.cache'));
    final resolvedTempRoot =
        tempRoot ?? Directory(p.join(baseDir.path, '.temp'));
    _ensureScaffold(
      baseDir: baseDir,
      cacheRoot: resolvedCacheRoot,
      tempRoot: resolvedTempRoot,
    );
    return StoragePaths._(
      baseDir: baseDir,
      cacheRoot: resolvedCacheRoot,
      tempRoot: resolvedTempRoot,
    );
  }

  final Directory baseDir;
  final Directory cacheRoot;
  final Directory tempRoot;

  Directory get libraryRoot => Directory(p.join(baseDir.path, 'library'));
  Directory get booksRoot => Directory(p.join(baseDir.path, 'books'));

  static Future<StoragePaths> initialize() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final tempDir = await getTemporaryDirectory();

    final baseDir = Directory(p.join(appSupportDir.path, 'full_reader'));
    final cacheRoot = Directory(p.join(tempDir.path, 'full_reader_cache'));
    final tempRoot = Directory(p.join(tempDir.path, 'full_reader_temp'));
    _ensureScaffold(
      baseDir: baseDir,
      cacheRoot: cacheRoot,
      tempRoot: tempRoot,
    );

    return StoragePaths._(
      baseDir: baseDir,
      cacheRoot: cacheRoot,
      tempRoot: tempRoot,
    );
  }

  static void _ensureScaffold({
    required Directory baseDir,
    required Directory cacheRoot,
    required Directory tempRoot,
  }) {
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    if (!cacheRoot.existsSync()) {
      cacheRoot.createSync(recursive: true);
    }
    if (!tempRoot.existsSync()) {
      tempRoot.createSync(recursive: true);
    }

    final libraryRoot = Directory(p.join(baseDir.path, 'library'));
    final booksRoot = Directory(p.join(baseDir.path, 'books'));
    final tmpRoot = Directory(p.join(libraryRoot.path, '.tmp'));

    if (!libraryRoot.existsSync()) {
      libraryRoot.createSync(recursive: true);
    }
    if (!booksRoot.existsSync()) {
      booksRoot.createSync(recursive: true);
    }
    if (!tmpRoot.existsSync()) {
      tmpRoot.createSync(recursive: true);
    }
  }
}
