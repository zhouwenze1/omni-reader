import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:infrastructure_data/data.dart';
import 'package:intl/intl.dart';

import '../../../di/repositories_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/controller/settings_controller.dart';
import '../controller/library_controller.dart';
import '../controller/library_state.dart';

class LibraryPageActions {
  const LibraryPageActions._();

  static String? resolveCoverPath(
      DataModule dataModule, LibraryIndexEntry entry) {
    final rel = entry.coverRelPath;
    if (rel == null || rel.isEmpty) {
      return null;
    }
    return '${dataModule.storagePaths.libraryRoot.path}/${entry.bookUid}/$rel';
  }

  static String formatDate(BuildContext context, DateTime value) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('yyyy-MM-dd', localeTag).format(value);
  }

  static String currentCollectionLabel(
    BuildContext context,
    DesktopLibraryState state,
  ) {
    final l10n = context.l10n;
    final selectedId = state.selectedCollectionId;
    if (selectedId == null) {
      return l10n.allCollections;
    }
    for (final collection in state.collections) {
      if (collection.id == selectedId) {
        return collection.name;
      }
    }
    return l10n.unknownCollection;
  }

  static Future<void> showCreateCollectionDialog(
    BuildContext context,
    DesktopLibraryController controller,
  ) async {
    final l10n = context.l10n;
    final input = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newCollection),
        content: TextField(
          controller: input,
          decoration: InputDecoration(hintText: l10n.inputCollectionName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    if (created == true) {
      await controller.createCollection(input.text);
    }
  }

  static Future<void> _showRenameCollectionDialog(
    BuildContext context,
    DesktopLibraryController controller,
    Collection collection,
  ) async {
    final l10n = context.l10n;
    final input = TextEditingController(text: collection.name);
    final rename = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameCollection),
        content: TextField(
          controller: input,
          decoration: InputDecoration(hintText: l10n.inputCollectionNewName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (rename == true) {
      try {
        await controller.renameCollection(collection.id, input.text);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }

  static Future<void> showManageCollectionsDialog(
    BuildContext context,
    DesktopLibraryController controller,
  ) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, __) {
          final state = ref.watch(desktopLibraryControllerProvider);
          return AlertDialog(
            title: Text(l10n.manageCollection),
            content: SizedBox(
              width: 420,
              child: state.collections.isEmpty
                  ? Center(child: Text(l10n.noCollectionYet))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.collections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final collection = state.collections[index];
                        final isDefault =
                            collection.id == state.defaultCollectionId;
                        final count =
                            state.collectionBookUids[collection.id]?.length ??
                                0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(collection.name),
                          subtitle: Text(l10n.booksCount(count)),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: l10n.renameCollection,
                                onPressed: isDefault
                                    ? null
                                    : () => _showRenameCollectionDialog(
                                          context,
                                          controller,
                                          collection,
                                        ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                onPressed: isDefault
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await _confirmDeleteCollection(
                                          context,
                                          collection,
                                          count,
                                        );
                                        if (confirmed == true) {
                                          await controller.deleteCollection(
                                            collection.id,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    showCreateCollectionDialog(context, controller),
                child: Text(l10n.newCollection),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> showBookCollectionsDialog(
    BuildContext context,
    DesktopLibraryController controller,
    LibraryIndexEntry entry,
    DesktopLibraryState state,
  ) async {
    if (state.collections.isEmpty) {
      return;
    }

    final l10n = context.l10n;
    final selectedCollectionIds = state.collectionsOfBook(entry.bookUid);
    if (selectedCollectionIds.any(
      (id) => id != state.defaultCollectionId,
    )) {
      selectedCollectionIds.remove(state.defaultCollectionId);
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.collectionsForBookTitle(entry.title)),
            content: SizedBox(
              width: 380,
              child: ListView(
                shrinkWrap: true,
                children: state.collections.map((collection) {
                  final isDefault = collection.id == state.defaultCollectionId;
                  return CheckboxListTile(
                    value: selectedCollectionIds.contains(collection.id),
                    title: Text(collection.name),
                    subtitle: isDefault ? Text(l10n.uncategorized) : null,
                    onChanged: isDefault
                        ? null
                        : (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedCollectionIds.add(collection.id);
                              } else {
                                selectedCollectionIds.remove(collection.id);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    showCreateCollectionDialog(context, controller),
                child: Text(l10n.newCollection),
              ),
              FilledButton(
                onPressed: () async {
                  await controller.setBookCollections(
                    bookUid: entry.bookUid,
                    collectionIds: selectedCollectionIds,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<bool?> _confirmDeleteCollection(
    BuildContext context,
    Collection collection,
    int count,
  ) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '删除合集' : 'Delete collection'),
        content: Text(
          isZh
              ? '确定删除“${collection.name}”吗？将删除其中的归属关系，但不会删除书籍。当前包含 $count 本书。'
              : 'Delete “${collection.name}”? Books will remain in the library. It currently contains $count books.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  static Future<void> showAddSelectedDialog(
    BuildContext context,
    DesktopLibraryController controller,
    DesktopLibraryState state,
  ) async {
    if (state.selectedBookUids.isEmpty || state.collections.isEmpty) {
      return;
    }
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );
    final targetCollections = state.collections
        .where((collection) => collection.id != state.defaultCollectionId)
        .toList();
    if (targetCollections.isEmpty) {
      return;
    }
    int? selectedCollectionId = targetCollections.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isZh ? '加入合集' : 'Add to collection'),
          content: DropdownButtonFormField<int>(
            initialValue: selectedCollectionId,
            decoration: InputDecoration(
              labelText: isZh ? '目标合集' : 'Target collection',
              border: const OutlineInputBorder(),
            ),
            items: targetCollections
                .map(
                  (collection) => DropdownMenuItem<int>(
                    value: collection.id,
                    child: Text(collection.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              selectedCollectionId = value;
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: selectedCollectionId == null
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: Text(isZh ? '加入' : 'Add'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && selectedCollectionId != null) {
      await controller.addBooksToCollection(
        selectedCollectionId!,
        state.selectedBookUids,
      );
    }
  }

  static Future<void> deleteBook(
    BuildContext context,
    DesktopLibraryController controller,
    String bookUid,
  ) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteBook(bookUid);
    }
  }

  static Future<void> deleteSelectedBooks(
    BuildContext context,
    DesktopLibraryController controller,
    DesktopLibraryState state,
  ) async {
    if (state.selectedBookUids.isEmpty) {
      return;
    }
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(
            l10n.deleteSelectedBooksMessage(state.selectedBookUids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await controller.deleteBooks(state.selectedBookUids);
      controller.exitSelectionMode();
    }
  }

  static Future<void> showMoveSelectedDialog(
    BuildContext context,
    DesktopLibraryController controller,
    DesktopLibraryState state,
  ) async {
    if (state.selectedBookUids.isEmpty || state.collections.isEmpty) {
      return;
    }
    final l10n = context.l10n;
    int? selectedCollectionId =
        state.selectedCollectionId ?? state.collections.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.moveSelectedBooks),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.selectedBooksCount(state.selectedBookUids.length)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: selectedCollectionId,
                  decoration: InputDecoration(
                    labelText: l10n.targetCollection,
                    border: const OutlineInputBorder(),
                  ),
                  items: state.collections
                      .map(
                        (collection) => DropdownMenuItem<int>(
                          value: collection.id,
                          child: Text(collection.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCollectionId = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: selectedCollectionId == null
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: Text(l10n.move),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && selectedCollectionId != null) {
      await controller.moveBooksToCollection(
        bookUids: state.selectedBookUids,
        collectionId: selectedCollectionId!,
      );
      controller.exitSelectionMode();
    }
  }

  static Future<void> importBooks(BuildContext context, WidgetRef ref) async {
    final importKind = await _showImportModeDialog(context);
    if (importKind == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final l10n = context.l10n;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );
    List<String> paths = <String>[];
    Collection? folderCollection;
    if (importKind == _LibraryImportKind.files) {
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

      paths = picked?.files
              .map((file) => file.path)
              .whereType<String>()
              .where((path) => path.isNotEmpty)
              .toList() ??
          <String>[];
    } else {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: isZh ? '选择 EPUB 文件夹' : 'Select EPUB Folder',
      );
      if (directoryPath == null || directoryPath.trim().isEmpty) {
        return;
      }
      paths = importKind == _LibraryImportKind.folderOneLevel
          ? await _collectEpubFilesOneLevel(directoryPath)
          : await _collectEpubFilesRecursively(directoryPath);
      if (paths.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isZh
                    ? '选中的文件夹中没有找到 EPUB 文件'
                    : 'No EPUB files found in the selected folder.',
              ),
            ),
          );
        }
        return;
      }
      folderCollection = await ref
          .read(collectionRepositoryProvider)
          .ensureCollection(_folderCollectionName(directoryPath));
    }

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

    final appSettings = ref.read(settingsControllerProvider).app;
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final currentState = ref.read(desktopLibraryControllerProvider);
    final currentCollectionId = folderCollection?.id ??
        currentState.selectedCollectionId ??
        currentState.defaultCollectionId;

    var importedCount = 0;
    var alreadyCount = 0;
    var failedCount = 0;
    final importedBookUids = <String>{};

    for (final path in paths) {
      final result =
          await ref.read(importRepositoryProvider).importBookFromFile(
                path,
                debugMode: appSettings.debugImport,
                options: options,
              );
      if (result.alreadyImported) {
        alreadyCount += 1;
      } else if (result.task.status == ImportTaskStatus.success) {
        importedCount += 1;
        if (result.bookUid != null) {
          importedBookUids.add(result.bookUid!);
        }
      } else {
        failedCount += 1;
      }
    }

    if (currentCollectionId != null && importedBookUids.isNotEmpty) {
      await controller.addBooksToCollection(
        currentCollectionId,
        importedBookUids,
      );
      await controller.setCollectionFilter(currentCollectionId);
    } else {
      await controller.refresh();
    }

    if (!context.mounted) {
      return;
    }

    final message =
        '${l10n.imported}: $importedCount, ${l10n.alreadyImported}: $alreadyCount, ${l10n.importFailed}: $failedCount';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<_LibraryImportKind?> _showImportModeDialog(
    BuildContext context,
  ) {
    final l10n = context.l10n;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );
    return showDialog<_LibraryImportKind>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importBook),
        content: Text(
          isZh
              ? '选择导入本地文件，或扫描选中文件夹中的 EPUB。'
              : 'Choose local files or scan EPUB files from a folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () =>
                Navigator.of(context).pop(_LibraryImportKind.folder),
            child: Text(isZh ? '导入全部子文件夹' : 'Import Recursively'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(
              _LibraryImportKind.folderOneLevel,
            ),
            child: Text(isZh ? '导入一级子文件夹' : 'Import One Level'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_LibraryImportKind.files),
            child: Text(isZh ? '导入文件' : 'Import Files'),
          ),
        ],
      ),
    );
  }

  static Future<ImportBookOptions?> _showImportOptionsDialog(
    BuildContext context,
    List<String> paths,
  ) async {
    if (!_containsEpub(paths)) {
      return const ImportBookOptions();
    }

    final l10n = context.l10n;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'zh',
            );
    var enableSmartToc = true;

    return showDialog<ImportBookOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isZh ? 'EPUB 导入选项' : 'EPUB Import Options'),
            content: SizedBox(
              width: 420,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: enableSmartToc,
                controlAffinity: ListTileControlAffinity.leading,
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
                    enableSmartToc = value ?? true;
                  });
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    ImportBookOptions(
                      enableSmartTocReconciliation: enableSmartToc,
                    ),
                  );
                },
                child: Text(l10n.importBook),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _containsEpub(List<String> paths) {
    for (final path in paths) {
      if (EpubFileScanner.isEpubPath(path)) {
        return true;
      }
    }
    return false;
  }

  static Future<List<String>> _collectEpubFilesRecursively(
    String directoryPath,
  ) async {
    return EpubFileScanner.collectRecursively(directoryPath);
  }

  static Future<List<String>> _collectEpubFilesOneLevel(
    String directoryPath,
  ) async {
    return EpubFileScanner.collectOneLevel(directoryPath);
  }

  static String _folderCollectionName(String directoryPath) {
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

enum _LibraryImportKind { files, folder, folderOneLevel }
