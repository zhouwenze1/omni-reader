import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

class FileServiceImpl implements FileService {
  static final Map<String, Future<void>> _pathWriteQueue =
      <String, Future<void>>{};

  @override
  Future<void> ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<Map<String, dynamic>?> readJson(String path) async {
    final file = File(path);
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

  @override
  Future<void> writeJsonAtomic(String path, Map<String, dynamic> json) async {
    const encoder = JsonEncoder.withIndent('  ');
    await writeTextAtomic(path, encoder.convert(json));
  }

  @override
  Future<void> writeTextAtomic(String path, String content) async {
    await _runWithPathWriteLock(path, () async {
      final parent = Directory(p.dirname(path));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      final tempPath = '$path.__tmp__${DateTime.now().microsecondsSinceEpoch}';
      final tempFile = File(tempPath);
      await tempFile.writeAsString(content, flush: true);

      final targetFile = File(path);
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } on FileSystemException {
          // Another writer might have removed it between exists/delete checks.
          if (await targetFile.exists()) {
            rethrow;
          }
        }
      }
      await tempFile.rename(path);
    });
  }

  @override
  Future<String?> readText(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> appendLine(String path, String line) async {
    final parent = Directory(p.dirname(path));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final sink = File(path).openWrite(mode: FileMode.append);
    sink.writeln(line);
    await sink.flush();
    await sink.close();
  }

  @override
  Future<void> copyFile(String from, String to) async {
    final source = File(from);
    final parent = Directory(p.dirname(to));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await source.copy(to);
  }

  @override
  Future<void> removeDir(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<List<String>> listDirs(String path) async {
    final root = Directory(path);
    if (!await root.exists()) {
      return const [];
    }

    final entities = await root
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    entities.sort((a, b) => a.path.compareTo(b.path));
    return entities.map((dir) => dir.path).toList();
  }

  @override
  Future<void> moveDirAtomic(String from, String to) async {
    final source = Directory(from);
    if (!await source.exists()) {
      throw StateError('Source directory does not exist: $from');
    }

    final target = Directory(to);
    if (await target.exists()) {
      throw StateError('Target directory already exists: $to');
    }

    final parent = Directory(p.dirname(to));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await source.rename(to);
  }

  @override
  Future<bool> exists(String path) {
    return FileSystemEntity.type(
      path,
    ).then((type) => type != FileSystemEntityType.notFound);
  }

  Future<void> _runWithPathWriteLock(
    String path,
    Future<void> Function() operation,
  ) async {
    final lockKey = p.normalize(path).toLowerCase();
    final previous = _pathWriteQueue[lockKey] ?? Future<void>.value();
    final currentCompleter = Completer<void>();
    _pathWriteQueue[lockKey] = currentCompleter.future;

    try {
      await previous.catchError((_) {});
      await operation();
      currentCompleter.complete();
    } catch (error, stackTrace) {
      if (!currentCompleter.isCompleted) {
        currentCompleter.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      if (identical(_pathWriteQueue[lockKey], currentCompleter.future)) {
        _pathWriteQueue.remove(lockKey);
      }
    }
  }
}
