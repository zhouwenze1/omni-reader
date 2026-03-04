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
      await controller.renameCollection(collection.id, input.text);
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
                                onPressed: () => _showRenameCollectionDialog(
                                  context,
                                  controller,
                                  collection,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                onPressed: () async {
                                  await controller
                                      .deleteCollection(collection.id);
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
    final l10n = context.l10n;
    final localSelected = {...state.collectionsOfBook(entry.bookUid)};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.collectionsForBookTitle(entry.title)),
            content: SizedBox(
              width: 380,
              child: state.collections.isEmpty
                  ? Text(l10n.noCollectionCreateFirst)
                  : ListView(
                      shrinkWrap: true,
                      children: state.collections.map((collection) {
                        final selected = localSelected.contains(collection.id);
                        return CheckboxListTile(
                          value: selected,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(collection.name),
                          onChanged: (value) async {
                            final shouldContain = value ?? false;
                            setDialogState(() {
                              if (shouldContain) {
                                localSelected.add(collection.id);
                              } else {
                                localSelected.remove(collection.id);
                              }
                            });
                            await controller.toggleBookInCollection(
                              collectionId: collection.id,
                              bookUid: entry.bookUid,
                              shouldContain: shouldContain,
                            );
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
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.done),
              ),
            ],
          );
        },
      ),
    );
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
    final l10n = context.l10n;
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

    final paths = picked?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList() ??
        <String>[];
    if (paths.isEmpty) {
      return;
    }

    final appSettings = ref.read(settingsControllerProvider).app;
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final currentCollectionId =
        ref.read(desktopLibraryControllerProvider).selectedCollectionId;

    var importedCount = 0;
    var alreadyCount = 0;
    var failedCount = 0;
    final importedOrExistingBookUids = <String>{};

    for (final path in paths) {
      final result =
          await ref.read(importRepositoryProvider).importBookFromFile(
                path,
                debugMode: appSettings.debugImport,
              );
      if (result.alreadyImported) {
        alreadyCount += 1;
      } else if (result.task.status == ImportTaskStatus.success) {
        importedCount += 1;
      } else {
        failedCount += 1;
      }
      final uid = result.bookUid;
      if (uid != null) {
        importedOrExistingBookUids.add(uid);
      }
    }

    if (currentCollectionId != null && importedOrExistingBookUids.isNotEmpty) {
      await controller.addBooksToCollection(
        currentCollectionId,
        importedOrExistingBookUids,
      );
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
}
