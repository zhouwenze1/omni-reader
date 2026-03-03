import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'library_state.dart';

final desktopLibraryControllerProvider =
    StateNotifierProvider<DesktopLibraryController, DesktopLibraryState>((ref) {
  final controller = DesktopLibraryController(
    bookRepository: ref.watch(bookRepositoryProvider),
    collectionRepository: ref.watch(collectionRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

class DesktopLibraryController extends StateNotifier<DesktopLibraryState> {
  DesktopLibraryController({
    required BookRepository bookRepository,
    required CollectionRepository collectionRepository,
  })  : _bookRepository = bookRepository,
        _collectionRepository = collectionRepository,
        super(const DesktopLibraryState.initial());

  final BookRepository _bookRepository;
  final CollectionRepository _collectionRepository;

  Future<void> load() async {
    state = state.copyWith(status: LibraryPageStatus.loading, clearError: true);
    try {
      final snapshot = await _loadSnapshot();
      final next = _buildStateFromSnapshot(snapshot);
      state = next;
    } catch (error) {
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Load library failed: $error',
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> setViewMode(LibraryViewMode mode) async {
    state = state.copyWith(viewMode: mode);
  }

  Future<void> setSortMode(LibrarySortMode mode) async {
    state = state.copyWith(sortMode: mode);
    await _reloadByCurrentQuery();
  }

  Future<void> setFilterPanelVisible(bool visible) async {
    state = state.copyWith(isFilterPanelVisible: visible);
  }

  Future<void> toggleFilterPanel() async {
    state = state.copyWith(isFilterPanelVisible: !state.isFilterPanelVisible);
  }

  Future<void> setFormats(Set<String> formats) async {
    state = state.copyWith(
      filters: LibraryFilters(
        formats: formats,
        progress: state.filters.progress,
        categoryIds: state.filters.categoryIds,
      ),
    );
    await _reloadByCurrentQuery();
  }

  Future<void> setProgressBucket(LibraryProgressBucket progress) async {
    state = state.copyWith(
      filters: LibraryFilters(
        formats: state.filters.formats,
        progress: progress,
        categoryIds: state.filters.categoryIds,
      ),
    );
    await _reloadByCurrentQuery();
  }

  Future<void> setCategories(Set<String> categoryIds) async {
    state = state.copyWith(
      filters: LibraryFilters(
        formats: state.filters.formats,
        progress: state.filters.progress,
        categoryIds: categoryIds,
      ),
    );
    await _reloadByCurrentQuery();
  }

  Future<void> setCollectionFilter(int? collectionId) async {
    state = state.copyWith(selectedCollectionId: collectionId);
    await _reloadByCurrentQuery();
  }

  void enterSelectionMode({String? seedBookUid}) {
    final selected = <String>{...state.selectedBookUids};
    if (seedBookUid != null) {
      selected.add(seedBookUid);
    }
    state = state.copyWith(
      isSelectionMode: true,
      selectedBookUids: selected,
      selectedBookUid: seedBookUid ?? state.selectedBookUid,
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedBookUids: <String>{},
    );
  }

  void toggleSelectedBook(String bookUid) {
    final selected = <String>{...state.selectedBookUids};
    if (selected.contains(bookUid)) {
      selected.remove(bookUid);
    } else {
      selected.add(bookUid);
    }
    state = state.copyWith(
      isSelectionMode: true,
      selectedBookUids: selected,
      selectedBookUid: bookUid,
    );
  }

  void selectAllVisible() {
    state = state.copyWith(
      isSelectionMode: true,
      selectedBookUids: state.filteredItems.map((it) => it.bookUid).toSet(),
    );
  }

  void clearSelectedBooks() {
    state = state.copyWith(selectedBookUids: <String>{});
  }

  void selectBook(String? bookUid) {
    state = state.copyWith(selectedBookUid: bookUid);
  }

  Future<void> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _collectionRepository.createCollection(trimmed);
    await _reloadByCurrentQuery();
  }

  Future<void> renameCollection(int collectionId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _collectionRepository.renameCollection(collectionId, trimmed);
    await _reloadByCurrentQuery();
  }

  Future<void> deleteCollection(int collectionId) async {
    await _collectionRepository.deleteCollection(collectionId);
    if (state.selectedCollectionId == collectionId) {
      state = state.copyWith(clearSelectedCollection: true);
    }
    await _reloadByCurrentQuery();
  }

  Future<void> addBookToCollection(int collectionId, String bookUid) async {
    await _collectionRepository.addBookToCollection(collectionId, bookUid);
    await _reloadByCurrentQuery();
  }

  Future<void> addBooksToCollection(
    int collectionId,
    Iterable<String> bookUids,
  ) async {
    for (final uid in bookUids.toSet()) {
      await _collectionRepository.addBookToCollection(collectionId, uid);
    }
    await _reloadByCurrentQuery();
  }

  Future<void> removeBookFromCollection(
      int collectionId, String bookUid) async {
    await _collectionRepository.removeBookFromCollection(collectionId, bookUid);
    await _reloadByCurrentQuery();
  }

  Future<void> toggleBookInCollection({
    required int collectionId,
    required String bookUid,
    required bool shouldContain,
  }) async {
    if (shouldContain) {
      await _collectionRepository.addBookToCollection(collectionId, bookUid);
    } else {
      await _collectionRepository.removeBookFromCollection(
          collectionId, bookUid);
    }
    await _reloadByCurrentQuery();
  }

  Future<void> deleteBook(String bookUid) async {
    try {
      await _collectionRepository.removeBookFromAllCollections(bookUid);
      await _bookRepository.deleteBook(bookUid);
      await _reloadByCurrentQuery();
    } catch (error) {
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Delete failed: $error',
      );
    }
  }

  Future<void> deleteBooks(Iterable<String> bookUids) async {
    final ids = bookUids.toSet();
    if (ids.isEmpty) {
      return;
    }
    try {
      for (final uid in ids) {
        await _collectionRepository.removeBookFromAllCollections(uid);
        await _bookRepository.deleteBook(uid);
      }
      state = state.copyWith(selectedBookUids: <String>{});
      await _reloadByCurrentQuery();
    } catch (error) {
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Batch delete failed: $error',
      );
    }
  }

  Future<void> moveBooksToCollection({
    required Iterable<String> bookUids,
    required int collectionId,
  }) async {
    final ids = bookUids.toSet();
    if (ids.isEmpty) {
      return;
    }
    try {
      for (final uid in ids) {
        await _collectionRepository.removeBookFromAllCollections(uid);
        await _collectionRepository.addBookToCollection(collectionId, uid);
      }
      state = state.copyWith(selectedBookUids: <String>{});
      await _reloadByCurrentQuery();
    } catch (error) {
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Move to collection failed: $error',
      );
    }
  }

  Future<void> _reloadByCurrentQuery() async {
    try {
      final snapshot = await _loadSnapshot();
      state = _buildStateFromSnapshot(snapshot);
    } catch (error) {
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Reload failed: $error',
      );
    }
  }

  Future<_LibrarySnapshot> _loadSnapshot() async {
    final items = await _bookRepository.listLibraryIndex(
      sortMode: state.sortMode,
      filters: state.filters,
    );
    final collections = await _collectionRepository.listCollections();
    final collectionBookUids = <int, Set<String>>{};
    for (final collection in collections) {
      final collectionItems =
          await _collectionRepository.listCollectionItems(collection.id);
      collectionBookUids[collection.id] =
          collectionItems.map((it) => it.bookUid).toSet();
    }
    return _LibrarySnapshot(
      items: items,
      collections: collections,
      collectionBookUids: collectionBookUids,
    );
  }

  DesktopLibraryState _buildStateFromSnapshot(_LibrarySnapshot snapshot) {
    final allItems = snapshot.items;
    final collectionIds = snapshot.collections.map((it) => it.id).toSet();
    final selectedCollectionId =
        collectionIds.contains(state.selectedCollectionId)
            ? state.selectedCollectionId
            : null;
    final collectionBookUids = snapshot.collectionBookUids;
    final visibleItems = selectedCollectionId == null
        ? allItems
        : allItems
            .where(
              (item) => (collectionBookUids[selectedCollectionId] ?? const {})
                  .contains(item.bookUid),
            )
            .toList();

    final items = visibleItems;
    final formats = items.map((e) => e.format).toSet();
    final categories =
        items.map((e) => e.categoryId ?? '').where((e) => e.isNotEmpty).toSet();

    final filteredSelection = state.selectedBookUids
        .where((uid) => items.any((it) => it.bookUid == uid))
        .toSet();

    String? selectedBookUid = state.selectedBookUid;
    if (items.isEmpty) {
      selectedBookUid = null;
    } else if (selectedBookUid == null ||
        !items.any((item) => item.bookUid == selectedBookUid)) {
      selectedBookUid = items.first.bookUid;
    }

    return state.copyWith(
      status:
          items.isEmpty ? LibraryPageStatus.empty : LibraryPageStatus.normal,
      items: items,
      filteredItems: items,
      selectedBookUid: selectedBookUid,
      selectedCollectionId: selectedCollectionId,
      collections: snapshot.collections,
      collectionBookUids: collectionBookUids,
      availableFormats: formats,
      availableCategories: categories,
      selectedBookUids: filteredSelection,
      isSelectionMode: state.isSelectionMode && filteredSelection.isNotEmpty,
      clearError: true,
    );
  }
}

class _LibrarySnapshot {
  const _LibrarySnapshot({
    required this.items,
    required this.collections,
    required this.collectionBookUids,
  });

  final List<LibraryIndexEntry> items;
  final List<Collection> collections;
  final Map<int, Set<String>> collectionBookUids;
}
