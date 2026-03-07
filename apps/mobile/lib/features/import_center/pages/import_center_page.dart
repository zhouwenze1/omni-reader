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

    Future<void> importAndRefresh() async {
      final paths = await controller.pickFiles();
      if (paths.isEmpty) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final options = await _showImportOptionsDialog(context, paths);
      if (options == null) {
        return;
      }
      await controller.importPathsWithOptions(paths, options: options);
      ref.invalidate(libraryIndexProvider);
      await ref.read(mobileLibraryControllerProvider.notifier).refresh();
      await ref.read(meControllerProvider.notifier).refresh();
    }

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
            onTap: state.isImporting ? () {} : importAndRefresh,
          ),
          if (state.isImporting)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('\u6b63\u5728\u5bfc\u5165\u6587\u4ef6...')),
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

  Future<ImportBookOptions?> _showImportOptionsDialog(
    BuildContext context,
    List<String> paths,
  ) async {
    if (!_containsEpub(paths)) {
      return const ImportBookOptions();
    }

    final isZh =
        (Localizations.localeOf(context).languageCode).toLowerCase().startsWith(
              'zh',
            );
    var enableSmartToc = true;

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
                        ? '自动补齐缺失的章节目录，并尽量挂到正确父级下。'
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
                child: Text(isZh ? '开始导入' : 'Import'),
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
}
