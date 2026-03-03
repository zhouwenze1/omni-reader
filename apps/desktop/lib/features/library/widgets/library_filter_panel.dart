import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/app_localizations.dart';
import '../controller/library_controller.dart';
import '../controller/library_state.dart';
import 'library_filter_dropdown.dart';

class LibraryFilterPanel extends StatelessWidget {
  const LibraryFilterPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.onCreateCollection,
    required this.onManageCollections,
  });

  final DesktopLibraryState state;
  final DesktopLibraryController controller;
  final VoidCallback onCreateCollection;
  final VoidCallback onManageCollections;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedFormat =
        state.filters.formats.isEmpty ? 'ALL' : state.filters.formats.first;
    final selectedCategory = state.filters.categoryIds.isEmpty
        ? 'ALL'
        : state.filters.categoryIds.first;
    final selectedCollectionId = state.selectedCollectionId;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.filter, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(l10n.format),
        const SizedBox(height: 6),
        LibraryFilterDropdown<String>(
          value: selectedFormat,
          hintText: l10n.all,
          options: [
            LibraryFilterOption(value: 'ALL', label: l10n.all),
            ...state.availableFormats.map(
              (format) => LibraryFilterOption(
                value: format,
                label: format.toUpperCase(),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == 'ALL') {
              controller.setFormats(<String>{});
              return;
            }
            controller.setFormats(<String>{value});
          },
        ),
        const SizedBox(height: 10),
        Text(l10n.progress),
        const SizedBox(height: 6),
        LibraryFilterDropdown<LibraryProgressBucket>(
          value: state.filters.progress,
          hintText: l10n.all,
          options: [
            LibraryFilterOption(
              value: LibraryProgressBucket.all,
              label: l10n.all,
            ),
            LibraryFilterOption(
              value: LibraryProgressBucket.notStarted,
              label: l10n.notStarted,
            ),
            LibraryFilterOption(
              value: LibraryProgressBucket.inProgress,
              label: l10n.inProgress,
            ),
            LibraryFilterOption(
              value: LibraryProgressBucket.completed,
              label: l10n.completed,
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              controller.setProgressBucket(value);
            }
          },
        ),
        const SizedBox(height: 10),
        Text(l10n.category),
        const SizedBox(height: 6),
        LibraryFilterDropdown<String>(
          value: selectedCategory,
          hintText: l10n.all,
          options: [
            LibraryFilterOption(value: 'ALL', label: l10n.all),
            ...state.availableCategories.map(
              (category) => LibraryFilterOption(
                value: category,
                label: category,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == 'ALL') {
              controller.setCategories(<String>{});
              return;
            }
            controller.setCategories(<String>{value});
          },
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 6),
        Text(l10n.collection),
        const SizedBox(height: 6),
        LibraryFilterDropdown<int?>(
          value: selectedCollectionId,
          hintText: l10n.allCollections,
          options: [
            LibraryFilterOption<int?>(
              value: null,
              label: l10n.allCollections,
            ),
            ...state.collections.map(
              (collection) => LibraryFilterOption<int?>(
                value: collection.id,
                label: collection.name,
              ),
            ),
          ],
          onChanged: (value) => controller.setCollectionFilter(value),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onCreateCollection,
          icon: const Icon(Icons.add),
          label: Text(l10n.newCollection),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onManageCollections,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(l10n.manageCollection),
        ),
      ],
    );
  }
}
