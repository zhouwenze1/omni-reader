import 'dart:convert';

import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../services/storage_paths.dart';

class AnnotationRepositoryImpl implements AnnotationRepository {
  AnnotationRepositoryImpl({
    required StoragePaths storagePaths,
    required FileService fileService,
  })  : _storagePaths = storagePaths,
        _fileService = fileService;

  final StoragePaths _storagePaths;
  final FileService _fileService;

  @override
  Future<List<Annotation>> listAnnotations(String bookUid) async {
    final jsonlPath = p.join(
      _storagePaths.libraryRoot.path,
      bookUid,
      'annotations.jsonl',
    );

    final text = await _fileService.readText(jsonlPath);
    if (text == null || text.trim().isEmpty) {
      return const [];
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    return lines.map((line) {
      final json = jsonDecode(line) as Map;
      return Annotation.fromJson(
        json.map((key, value) => MapEntry('$key', value)),
      );
    }).toList();
  }

  @override
  Future<void> appendAnnotation(String bookUid, Annotation annotation) {
    final jsonlPath = p.join(
      _storagePaths.libraryRoot.path,
      bookUid,
      'annotations.jsonl',
    );
    return _fileService.appendLine(jsonlPath, jsonEncode(annotation.toJson()));
  }

  @override
  Future<void> replaceAnnotations(
    String bookUid,
    List<Annotation> annotations,
  ) async {
    final jsonlPath = p.join(
      _storagePaths.libraryRoot.path,
      bookUid,
      'annotations.jsonl',
    );

    final buffer = StringBuffer();
    for (final annotation in annotations) {
      buffer.writeln(jsonEncode(annotation.toJson()));
    }

    await _fileService.writeTextAtomic(jsonlPath, buffer.toString());
  }
}
