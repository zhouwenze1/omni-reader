import 'dart:convert';
import 'dart:typed_data';

abstract interface class BookResourceSource {
  String get sourceId;

  Future<List<String>> listPaths();

  Future<bool> exists(String relativePath);

  Future<Uint8List?> readBytes(String relativePath);

  Future<String?> readText(String relativePath, {Encoding encoding = utf8});

  String? contentTypeFor(String relativePath);

  Future<void> close();
}
