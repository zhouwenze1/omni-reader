import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../utils/mime_utils.dart';
import '../utils/path_utils.dart';
import 'book_resource_source.dart';

class DirectoryResourceSource implements BookResourceSource {
  DirectoryResourceSource({
    required this.sourceId,
    required String rootDirectory,
  }) : _rootDirectory = Directory(rootDirectory);

  @override
  final String sourceId;

  final Directory _rootDirectory;

  @override
  Future<List<String>> listPaths() async {
    if (!await _rootDirectory.exists()) {
      return const <String>[];
    }
    final paths = <String>[];
    await for (final entity in _rootDirectory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relative = PathUtils.relativeToDirectory(
        _rootDirectory.path,
        entity.path,
      );
      paths.add(relative);
    }
    paths.sort();
    return paths;
  }

  @override
  Future<bool> exists(String relativePath) {
    return File(_resolvePath(relativePath)).exists();
  }

  @override
  Future<Uint8List?> readBytes(String relativePath) async {
    final file = File(_resolvePath(relativePath));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<String?> readText(
    String relativePath, {
    Encoding encoding = utf8,
  }) async {
    final file = File(_resolvePath(relativePath));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString(encoding: encoding);
  }

  @override
  String? contentTypeFor(String relativePath) {
    return MimeUtils.byPath(relativePath);
  }

  String _resolvePath(String relativePath) {
    final normalized = PathUtils.normalizeRelative(relativePath);
    return PathUtils.joinNative(_rootDirectory.path, normalized);
  }

  @override
  Future<void> close() async {}
}

