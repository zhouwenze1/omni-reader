import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

class EpubFileScanner {
  const EpubFileScanner._();

  /// 导入器支持的全部扩展名(与桌面端文件选择器的 allowedExtensions 一致)。
  static const List<String> supportedExtensions = [
    'epub',
    'pdf',
    'ldf',
    'zip',
    'cbz',
    'webpub',
    'lpf',
    'mp3',
    'm4b',
  ];

  static bool isEpubPath(String path) {
    return p.extension(path.trim()).toLowerCase() == '.epub';
  }

  /// 是否为导入器支持的书文件(拖拽导入按此过滤)。
  static bool isSupportedBookPath(String path) {
    final ext = p.extension(path.trim()).toLowerCase();
    if (ext.isEmpty) {
      return false;
    }
    return supportedExtensions.contains(ext.substring(1));
  }

  static Future<List<String>> collectRecursively(String directoryPath) async {
    return _collect(directoryPath);
  }

  /// Collects EPUB files from [directoryPath] and its direct child folders.
  ///
  /// Files below the first child-folder level are intentionally ignored.
  static Future<List<String>> collectOneLevel(String directoryPath) async {
    return _collect(directoryPath, maxDepth: 1);
  }

  static Future<List<String>> _collect(
    String directoryPath, {
    int? maxDepth,
  }) async {
    final root = Directory(directoryPath);
    if (!await root.exists()) {
      return const <String>[];
    }

    final results = <String>[];
    final visitedDirs = <String>{};
    final seenFiles = <String>{};
    final pending = Queue<_PendingDirectory>()..add(_PendingDirectory(root, 0));

    while (pending.isNotEmpty) {
      final pendingDirectory = pending.removeFirst();
      final dir = pendingDirectory.directory;
      final dirKey = p.normalize(dir.path).toLowerCase();
      if (!visitedDirs.add(dirKey)) {
        continue;
      }

      Stream<FileSystemEntity> stream;
      try {
        stream = dir.list(followLinks: false);
      } on FileSystemException {
        continue;
      }

      try {
        await for (final entity in stream) {
          if (entity is Directory) {
            if (maxDepth == null || pendingDirectory.depth < maxDepth) {
              pending.add(
                _PendingDirectory(entity, pendingDirectory.depth + 1),
              );
            }
            continue;
          }
          if (entity is! File) {
            continue;
          }

          final path = entity.path.trim();
          if (!isEpubPath(path)) {
            continue;
          }

          final fileKey = p.normalize(path).toLowerCase();
          if (seenFiles.add(fileKey)) {
            results.add(path);
          }
        }
      } on FileSystemException {
        continue;
      }
    }

    results.sort();
    return results;
  }
}

class _PendingDirectory {
  const _PendingDirectory(this.directory, this.depth);

  final Directory directory;
  final int depth;
}
