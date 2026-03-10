import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

class EpubFileScanner {
  const EpubFileScanner._();

  static bool isEpubPath(String path) {
    return p.extension(path.trim()).toLowerCase() == '.epub';
  }

  static Future<List<String>> collectRecursively(String directoryPath) async {
    final root = Directory(directoryPath);
    if (!await root.exists()) {
      return const <String>[];
    }

    final results = <String>[];
    final visitedDirs = <String>{};
    final seenFiles = <String>{};
    final pending = Queue<Directory>()..add(root);

    while (pending.isNotEmpty) {
      final dir = pending.removeFirst();
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
            pending.add(entity);
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
