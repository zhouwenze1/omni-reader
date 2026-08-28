import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../artifacts/epub_artifact_generator.dart';
import '../artifacts/epub_reader_metadata_adapter.dart';
import '../models/epub_book_package.dart';
import 'epub_reader_package_export.dart';

class EpubReaderPackageWriter {
  EpubReaderPackageWriter({
    EpubArtifactGenerator? artifactGenerator,
  }) : _artifactGenerator = artifactGenerator ?? EpubArtifactGenerator();

  final EpubArtifactGenerator _artifactGenerator;

  Future<EpubReaderPackageExport> export(
    EpubBookPackage package, {
    required String outputDirectoryPath,
    required String bookUuid,
    bool includeArtifacts = true,
    String archiveFileName = 'book.epub',
    Map<String, Object?>? lastLocator,
    DateTime? updatedAt,
  }) async {
    final exportPackage = await _preparePackage(
      package,
      includeArtifacts: includeArtifacts,
    );

    final outputDir = Directory(outputDirectoryPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final archivePath = p.join(outputDirectoryPath, archiveFileName);
    await _copyArchive(
      sourcePath: exportPackage.sourcePath,
      targetPath: archivePath,
    );

    final metadataPath = p.join(outputDirectoryPath, 'meta.json');
    final metadataJson = EpubReaderMetadataAdapter.toReaderMetadataJson(
      exportPackage,
      bookUuid: bookUuid,
      lastLocator: lastLocator,
      updatedAt: updatedAt,
    );
    await _writeJsonAtomic(metadataPath, metadataJson);

    final artifactPaths = <String, String>{};
    if (includeArtifacts) {
      for (final entry in exportPackage.artifacts.toFileMap().entries) {
        final filePath = p.join(outputDirectoryPath, entry.key);
        await _writeJsonAtomic(filePath, entry.value);
        artifactPaths[entry.key] = filePath;
      }
    }

    return EpubReaderPackageExport(
      bookUuid: bookUuid,
      rootDirectoryPath: outputDirectoryPath,
      archivePath: archivePath,
      metadataPath: metadataPath,
      artifactPaths: artifactPaths,
    );
  }

  Future<EpubBookPackage> _preparePackage(
    EpubBookPackage package, {
    required bool includeArtifacts,
  }) async {
    if (!includeArtifacts) {
      return package;
    }
    if (!_needsArtifacts(package)) {
      return package;
    }
    return _artifactGenerator.generateArtifacts(package);
  }

  bool _needsArtifacts(EpubBookPackage package) {
    final artifacts = package.artifacts;
    return artifacts.manifest == null ||
        artifacts.positions == null ||
        artifacts.content == null;
  }

  Future<void> _copyArchive({
    required String sourcePath,
    required String targetPath,
  }) async {
    final normalizedSource = p.normalize(sourcePath);
    final normalizedTarget = p.normalize(targetPath);
    if (normalizedSource == normalizedTarget) {
      return;
    }

    final targetFile = File(targetPath);
    final parentDir = targetFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw StateError('EPUB source file not found: $sourcePath');
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await sourceFile.copy(targetPath);
  }

  Future<void> _writeJsonAtomic(
    String filePath,
    Map<String, Object?> json,
  ) async {
    const encoder = JsonEncoder.withIndent('  ');
    await _writeTextAtomic(filePath, encoder.convert(json));
  }

  Future<void> _writeTextAtomic(String filePath, String content) async {
    final targetFile = File(filePath);
    final parentDir = targetFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final tempPath =
        '$filePath.__tmp__${DateTime.now().microsecondsSinceEpoch}';
    final tempFile = File(tempPath);
    await tempFile.writeAsString(content, flush: true);

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(filePath);
  }
}
