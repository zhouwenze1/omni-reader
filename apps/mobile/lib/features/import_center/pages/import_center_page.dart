import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:infrastructure_data/data.dart';

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
        title: const Text('导入中心'),
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
            title: '选择本地文件',
            subtitle: '支持 EPUB、PDF、LDF、CBZ 及音频书格式。',
            onTap: state.isImporting ? () {} : () => _importFiles(context, ref),
          ),
          const SizedBox(height: 12),
          ImportSourceTile(
            icon: Icons.drive_folder_upload_outlined,
            title: '导入文件夹',
            subtitle: '递归扫描 EPUB，并按文件夹名自动创建合集。',
            onTap:
                state.isImporting ? () {} : () => _importFolder(context, ref),
          ),
          const SizedBox(height: 12),
          ImportSourceTile(
            icon: Icons.folder_copy_outlined,
            title: '导入一级子文件夹',
            subtitle: '扫描当前文件夹和直属子文件夹，忽略更深层目录。',
            onTap: state.isImporting
                ? () {}
                : () => _importFolder(
                      context,
                      ref,
                      directChildrenOnly: true,
                    ),
          ),
          if (state.isImporting)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 12),
                    Expanded(child: Text('正在导入...')),
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
                '近期任务  成功 ${state.successCount} / 已存在 ${state.alreadyImportedCount} / 失败 ${state.failedCount}',
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

  Future<void> _importFolder(
    BuildContext context,
    WidgetRef ref, {
    bool directChildrenOnly = false,
  }) async {
    final controller = ref.read(importControllerProvider.notifier);
    final selection = await controller.pickFolderImportSelection(
      directChildrenOnly: directChildrenOnly,
    );
    if (selection == null || !context.mounted) {
      return;
    }

    if (selection.paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_noEpubInFolderText(context))),
        );
      }
      await controller.cleanupFolderImportSelection(selection);
      return;
    }

    final options = await _showImportOptionsDialog(context, selection.paths);
    if (options == null) {
      await controller.cleanupFolderImportSelection(selection);
      return;
    }

    final libraryController =
        ref.read(mobileLibraryControllerProvider.notifier);
    final collection = await libraryController.ensureCollection(
      selection.collectionName,
    );
    try {
      final results = await controller.importPathsWithOptions(
        selection.paths,
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
    } finally {
      await controller.cleanupFolderImportSelection(selection);
    }
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
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );

    return showDialog<ImportBookOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isZh ? 'EPUB 导入选项' : 'EPUB Import Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: enableSmartToc,
                  title: Text(
                    isZh ? '智能修复目录结构' : 'Smart TOC reconciliation',
                  ),
                  subtitle: Text(
                    isZh
                        ? '自动补齐缺失的章节目录，并尽量挂到合适的父级节点下。'
                        : 'Fill missing spine chapters and attach them to likely section parents.',
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
                child: Text(isZh ? '取消' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    ImportBookOptions(
                      enableSmartTocReconciliation: enableSmartToc,
                    ),
                  );
                },
                child: Text(isZh ? '导入' : 'Import'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _containsEpub(List<String> paths) {
    for (final path in paths) {
      if (EpubFileScanner.isEpubPath(path)) {
        return true;
      }
    }
    return false;
  }

  String _noEpubInFolderText(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );
    return isZh
        ? '选中的文件夹中没有找到 EPUB 文件'
        : 'No EPUB files found in the selected folder.';
  }
}
