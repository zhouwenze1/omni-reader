import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/repositories_providers.dart';
import 'import_state.dart';

final importControllerProvider =
    StateNotifierProvider<ImportController, ImportState>((ref) {
  return ImportController(
    importRepository: ref.watch(importRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

class ImportController extends StateNotifier<ImportState> {
  static const MethodChannel _folderImportChannel =
      MethodChannel('reader_mobile/folder_import');

  ImportController({
    required ImportRepository importRepository,
    required SettingsRepository settingsRepository,
  })  : _importRepository = importRepository,
        _settingsRepository = settingsRepository,
        super(const ImportState.initial());

  final ImportRepository _importRepository;
  final SettingsRepository _settingsRepository;

  Future<List<String>> pickFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'epub',
        'pdf',
        'ldf',
        'zip',
        'cbz',
        'webpub',
        'lpf',
        'mp3',
        'm4b',
      ],
    );

    return picked?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList() ??
        <String>[];
  }

  Future<String?> pickDirectory() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select EPUB Folder',
    );
  }

  Future<FolderImportSelection?> pickFolderImportSelection({
    bool directChildrenOnly = false,
  }) async {
    if (Platform.isAndroid) {
      final result = await _folderImportChannel.invokeMethod<Object?>(
        'pickEpubFilesFromDirectory',
        <String, Object?>{
          'maxDepth': directChildrenOnly ? 1 : null,
        },
      );
      if (result == null) {
        return null;
      }
      if (result is! Map) {
        throw StateError('Unexpected folder import result type: $result');
      }

      final rawPaths = result['paths'];
      final paths = rawPaths is List
          ? rawPaths
              .map((value) => '$value'.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
      final rawCleanupRoots = result['cleanupRoots'];
      final cleanupRoots = rawCleanupRoots is List
          ? rawCleanupRoots
              .map((value) => '$value'.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
      final collectionName = '${result['directoryName'] ?? ''}'.trim();
      return FolderImportSelection(
        paths: paths,
        collectionName: collectionName.isEmpty
            ? CollectionPresets.uncategorizedName
            : collectionName,
        transientPaths: paths,
        cleanupRoots: cleanupRoots,
      );
    }

    final directoryPath = await pickDirectory();
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      return null;
    }

    final paths = directChildrenOnly
        ? await collectEpubFilesOneLevel(directoryPath)
        : await collectEpubFilesRecursively(directoryPath);
    return FolderImportSelection(
      paths: paths,
      collectionName: _folderCollectionName(directoryPath),
      transientPaths: const <String>[],
      cleanupRoots: const <String>[],
    );
  }

  Future<List<String>> collectEpubFilesRecursively(String directoryPath) async {
    return EpubFileScanner.collectRecursively(directoryPath);
  }

  Future<List<String>> collectEpubFilesOneLevel(String directoryPath) async {
    return EpubFileScanner.collectOneLevel(directoryPath);
  }

  Future<void> cleanupFolderImportSelection(
    FolderImportSelection selection,
  ) async {
    for (final root in selection.cleanupRoots) {
      try {
        final dir = Directory(root);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
    for (final path in selection.transientPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<List<ImportResult>> importPaths(List<String> paths) {
    return importPathsWithOptions(paths);
  }

  Future<List<ImportResult>> importPathsWithOptions(
    List<String> paths, {
    ImportBookOptions options = const ImportBookOptions(),
  }) async {
    if (paths.isEmpty || state.isImporting) {
      return const <ImportResult>[];
    }

    state = state.copyWith(isImporting: true, clearError: true);
    final results = <ImportResult>[];
    try {
      final appSettings = await _settingsRepository.getAppSettings();
      final nextTasks = <ImportTask>[...state.tasks];
      for (final path in paths) {
        final result = await _importRepository.importBookFromFile(
          path,
          debugMode: appSettings.debugImport,
          options: options,
        );
        results.add(result);
        nextTasks.insert(0, result.task);
        state = state.copyWith(tasks: List<ImportTask>.from(nextTasks));
      }
      state = state.copyWith(isImporting: false, clearError: true);
      return results;
    } catch (error) {
      state = state.copyWith(
        isImporting: false,
        errorMessage: 'Import failed: $error',
      );
      return results;
    }
  }

  Future<void> pickAndImport({
    ImportBookOptions options = const ImportBookOptions(),
  }) async {
    final paths = await pickFiles();
    await importPathsWithOptions(paths, options: options);
  }

  void clearTasks() {
    state = state.copyWith(tasks: const <ImportTask>[], clearError: true);
  }

  String _folderCollectionName(String directoryPath) {
    final normalized = directoryPath.replaceAll('\\', '/');
    final segments =
        normalized.split('/').where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return CollectionPresets.uncategorizedName;
    }
    return segments.last.trim().isEmpty
        ? CollectionPresets.uncategorizedName
        : segments.last.trim();
  }
}

class FolderImportSelection {
  const FolderImportSelection({
    required this.paths,
    required this.collectionName,
    required this.transientPaths,
    required this.cleanupRoots,
  });

  final List<String> paths;
  final String collectionName;
  final List<String> transientPaths;
  final List<String> cleanupRoots;
}
