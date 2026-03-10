import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/providers.dart';
import '../../library/controller/library_controller.dart';
import '../../me/controller/me_controller.dart';
import '../controller/import_controller.dart';
import '../widgets/import_source_tile.dart';
import '../widgets/import_task_tile.dart';

class ImportCenterPage extends ConsumerWidget {
  const ImportCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u5bfc\u5165\u4e2d\u5fc3'),
        actions: [
          if (state.tasks.isNotEmpty)
            IconButton(
              onPressed: controller.clearTasks,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ImportSourceTile(
            icon: Icons.folder_open_outlined,
            title: '\u9009\u62e9\u672c\u5730\u6587\u4ef6',
            subtitle:
                '\u652f\u6301 EPUB\u3001PDF\u3001LDF\u3001CBZ \u53ca\u97f3\u9891\u4e66\u683c\u5f0f\u3002',
            onTap: state.isImporting ? () {} : () => _importFiles(context, ref),
          ),
          const SizedBox(height: 12),
          ImportSourceTile(
            icon: Icons.drive_folder_upload_outlined,
            title: '\u5bfc\u5165\u6587\u4ef6\u5939',
            subtitle:
                '\u9012\u5f52\u626b\u63cf EPUB\uff0c\u5e76\u6309\u6587\u4ef6\u5939\u540d\u81ea\u52a8\u521b\u5efa\u5408\u96c6\u3002',
            onTap:
                state.isImporting ? () {} : () => _importFolder(context, ref),
          ),
          if (state.isImporting)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 12),
                    Expanded(child: Text('\u6b63\u5728\u5bfc\u5165...')),
                  ],
                ),
              ),
            ),
          if (state.errorMessage != null)
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.errorMessage!),
              ),
            ),
          if (state.tasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                '\u8fd1\u671f\u4efb\u52a1  \u6210\u529f ${state.successCount} / \u5df2\u5b58\u5728 ${state.alreadyImportedCount} / \u5931\u8d25 ${state.failedCount}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...state.tasks.map((task) => ImportTaskTile(task: task)),
          ],
        ],
      ),
    );
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(importControllerProvider.notifier);
    final paths = await controller.pickFiles();
    if (paths.isEmpty || !context.mounted) {
      return;
    }

    final options = await _showImportOptionsDialog(context, paths);
    if (options == null) {
      return;
    }

    final results = await controller.importPathsWithOptions(
      paths,
      options: options,
    );
    final importedBookUids = _successfulImportedBookUids(results);
    final libraryState = ref.read(mobileLibraryControllerProvider);
    final targetCollectionId =
        libraryState.selectedCollectionId ?? libraryState.defaultCollectionId;
    if (targetCollectionId != null && importedBookUids.isNotEmpty) {
      await ref
          .read(mobileLibraryControllerProvider.notifier)
          .addBooksToCollection(
            targetCollectionId,
            importedBookUids,
          );
    } else {
      await ref.read(mobileLibraryControllerProvider.notifier).refresh();
    }
    await _refreshShellState(ref);
  }

  Future<void> _importFolder(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(importControllerProvider.notifier);
    final directoryPath = await controller.pickDirectory();
    if (directoryPath == null ||
        directoryPath.trim().isEmpty ||
        !context.mounted) {
      return;
    }

    final paths = await controller.collectEpubFilesRecursively(directoryPath);
    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u9009\u4e2d\u6587\u4ef6\u5939\u4e2d\u6ca1\u6709 EPUB \u6587\u4ef6'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    final options = await _showImportOptionsDialog(context, paths);
    if (options == null) {
      return;
    }

    final libraryController =
        ref.read(mobileLibraryControllerProvider.notifier);
    final collection = await libraryController.ensureCollection(
      _folderCollectionName(directoryPath),
    );
    final results = await controller.importPathsWithOptions(
      paths,
      options: options,
    );
    final importedBookUids = _successfulImportedBookUids(results);
    if (importedBookUids.isNotEmpty) {
      await libraryController.addBooksToCollection(
        collection.id,
        importedBookUids,
      );
    } else {
      await libraryController.refresh();
    }
    await libraryController.setCollectionFilter(collection.id);
    await _refreshShellState(ref);
  }

  Future<void> _refreshShellState(WidgetRef ref) async {
    ref.invalidate(libraryIndexProvider);
    await ref.read(mobileLibraryControllerProvider.notifier).refresh();
    await ref.read(meControllerProvider.notifier).refresh();
  }

  Set<String> _successfulImportedBookUids(List<ImportResult> results) {
    return results
        .where(
          (result) =>
              !result.alreadyImported &&
              result.task.status == ImportTaskStatus.success &&
              result.bookUid != null,
        )
        .map((result) => result.bookUid!)
        .toSet();
  }

  Future<ImportBookOptions?> _showImportOptionsDialog(
    BuildContext context,
    List<String> paths,
  ) async {
    if (!_containsEpub(paths)) {
      return const ImportBookOptions();
    }

    var enableSmartToc = true;

    return showDialog<ImportBookOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('EPUB Import Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: enableSmartToc,
                  title: const Text('Smart TOC reconciliation'),
                  subtitle: const Text(
                    'Fill missing spine chapters and attach them to likely section parents.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      enableSmartToc = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    ImportBookOptions(
                      enableSmartTocReconciliation: enableSmartToc,
                    ),
                  );
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _containsEpub(List<String> paths) {
    for (final path in paths) {
      if (path.toLowerCase().endsWith('.epub')) {
        return true;
      }
    }
    return false;
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
