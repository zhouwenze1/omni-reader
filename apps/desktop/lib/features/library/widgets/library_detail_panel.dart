import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/app_localizations.dart';
import '../controller/library_state.dart';
import 'book_cover.dart';
import 'book_meta_row.dart';

class LibraryDetailPanel extends StatelessWidget {
  const LibraryDetailPanel({
    super.key,
    required this.state,
    required this.coverPathResolver,
    required this.formatDate,
    required this.onContinueReading,
    required this.onOpenToc,
    required this.onDeleteBook,
    required this.onShowBookCollections,
    required this.onRemoveBookFromCollection,
    required this.onMoveSelected,
    required this.onDeleteSelected,
    required this.onExitSelectionMode,
  });

  final DesktopLibraryState state;
  final String? Function(LibraryIndexEntry entry) coverPathResolver;
  final String Function(DateTime value) formatDate;
  final ValueChanged<String> onContinueReading;
  final ValueChanged<String> onOpenToc;
  final ValueChanged<String> onDeleteBook;
  final ValueChanged<LibraryIndexEntry> onShowBookCollections;
  final Future<void> Function(int collectionId, String bookUid)
      onRemoveBookFromCollection;
  final VoidCallback onMoveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onExitSelectionMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.isSelectionMode) {
      final selectedCount = state.selectedBookUids.length;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch Actions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text('Selected books: $selectedCount'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: selectedCount == 0 ? null : onMoveSelected,
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Text('Move to collection'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: selectedCount == 0 ? null : onDeleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete selected'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onExitSelectionMode,
                child: const Text('Exit multi-select'),
              ),
            ),
          ],
        ),
      );
    }

    final entry = state.selectedItem;
    if (entry == null) {
      return Center(child: Text(l10n.selectBookToViewDetail));
    }

    final progress = ((entry.cachedProgress ?? 0) * 100).toStringAsFixed(1);
    final lastOpened = entry.lastOpenedAt;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: BookCover(
              filePath: coverPathResolver(entry),
              width: 140,
              height: 200,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            entry.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          BookMetaRow(label: l10n.author, value: entry.authors.join(' · ')),
          BookMetaRow(label: l10n.format, value: entry.format.toUpperCase()),
          BookMetaRow(label: l10n.progress, value: '$progress%'),
          BookMetaRow(
              label: l10n.category,
              value: entry.categoryId ?? l10n.uncategorized),
          BookMetaRow(
              label: l10n.importedAt, value: formatDate(entry.importedAt)),
          BookMetaRow(
            label: l10n.lastOpened,
            value: lastOpened == null ? '-' : formatDate(lastOpened),
          ),
          const SizedBox(height: 10),
          Text(l10n.collection, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _buildCollectionChips(l10n, state, entry),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => onShowBookCollections(entry),
              icon: const Icon(Icons.playlist_add),
              label: Text(l10n.addOrRemoveCollection),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => onContinueReading(entry.bookUid),
                  child: Text(l10n.continueReading),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onOpenToc(entry.bookUid),
                  child: Text(l10n.openToc),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDeleteBook(entry.bookUid),
              label: Text(l10n.deleteBook),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCollectionChips(
    AppLocalizations l10n,
    DesktopLibraryState state,
    LibraryIndexEntry entry,
  ) {
    final belongedIds = state.collectionsOfBook(entry.bookUid);
    if (belongedIds.isEmpty) {
      return [Text(l10n.noCollectionAdded)];
    }
    return state.collections
        .where((collection) => belongedIds.contains(collection.id))
        .map(
          (collection) => InputChip(
            label: Text(collection.name),
            onDeleted: () async {
              await onRemoveBookFromCollection(collection.id, entry.bookUid);
            },
          ),
        )
        .toList();
  }
}
