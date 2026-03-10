import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

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

  Future<List<String>> collectEpubFilesRecursively(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return const <String>[];
    }

    final paths = <String>[];
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (entity.path.toLowerCase().endsWith('.epub')) {
        paths.add(entity.path);
      }
    }
    paths.sort();
    return paths;
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
}
