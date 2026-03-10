import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'library_state.dart';

final mobileLibraryControllerProvider =
    StateNotifierProvider<MobileLibraryController, MobileLibraryState>((ref) {
  final controller = MobileLibraryController(
    bookRepository: ref.watch(bookRepositoryProvider),
    collectionRepository: ref.watch(collectionRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

class MobileLibraryController extends StateNotifier<MobileLibraryState> {
  MobileLibraryController({
    required BookRepository bookRepository,
    required CollectionRepository collectionRepository,
  })  : _bookRepository = bookRepository,
        _collectionRepository = collectionRepository,
        super(const MobileLibraryState.initial());

  final BookRepository _bookRepository;
  final CollectionRepository _collectionRepository;
  int _requestId = 0;

  Future<void> load() async {
    final requestId = ++_requestId;
    state = state.copyWith(status: LibraryPageStatus.loading, clearError: true);
    final sortMode = state.sortMode;
    final filters = state.filters;
    try {
      final nextState = await _queryState(
        sortMode: sortMode,
        filters: filters,
      );
      if (requestId != _requestId) {
        return;
      }
      state = nextState;
    } catch (error) {
      if (requestId != _requestId) {
        return;
      }
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Load failed: $error',
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> setViewMode(LibraryViewMode mode) async {
    state = state.copyWith(viewMode: mode);
  }

  Future<void> setSortMode(LibrarySortMode mode) async {
    state = state.copyWith(sortMode: mode);
    await _reload();
  }

  Future<void> setFormats(Set<String> formats) async {
    state = state.copyWith(
      filters: LibraryFilters(
        formats: formats,
        progress: state.filters.progress,
        categoryIds: state.filters.categoryIds,
      ),
    );
    await _reload();
  }

  Future<void> setProgressBucket(LibraryProgressBucket bucket) async {
    state = state.copyWith(
      filters: LibraryFilters(
        formats: state.filters.formats,
        progress: bucket,
        categoryIds: state.filters.categoryIds,
      ),
    );
    await _reload();
  }

  Future<void> setCategories(Set<String> categories) async {
    state = state.copyWith(
      filters: LibraryFilters(
        formats: state.filters.formats,
        progress: state.filters.progress,
        categoryIds: categories,
      ),
    );
    await _reload();
  }

  Future<void> setCollectionFilter(int? collectionId) async {
    state = state.copyWith(selectedCollectionId: collectionId);
    await _reload();
  }

  void enterSelectionMode({String? seedBookUid}) {
    final selected = <String>{...state.selectedBookUids};
    if (seedBookUid != null) {
      selected.add(seedBookUid);
    }
    state = state.copyWith(
      isSelectionMode: true,
      selectedBookUids: selected,
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
    );
  }

  void selectAllVisible() {
    state = state.copyWith(
      isSelectionMode: true,
      selectedBookUids: state.items.map((item) => item.bookUid).toSet(),
    );
  }

  void clearSelectedBooks() {
    state = state.copyWith(selectedBookUids: <String>{});
  }

  Future<Collection> ensureCollection(String name) async {
    final collection = await _collectionRepository.ensureCollection(name);
    await _reload();
    return collection;
  }

  Future<void> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _collectionRepository.ensureCollection(trimmed);
    await _reload();
  }

  Future<void> addBookToCollection(int collectionId, String bookUid) async {
    await _collectionRepository.removeBookFromAllCollections(bookUid);
    await _collectionRepository.addBookToCollection(collectionId, bookUid);
    await _reload();
  }

  Future<void> addBooksToCollection(
    int collectionId,
    Iterable<String> bookUids,
  ) async {
    for (final uid in bookUids.toSet()) {
      await _collectionRepository.removeBookFromAllCollections(uid);
      await _collectionRepository.addBookToCollection(collectionId, uid);
    }
    await _reload();
  }

  Future<void> deleteBook(String bookUid) async {
    await _collectionRepository.removeBookFromAllCollections(bookUid);
    await _bookRepository.deleteBook(bookUid);
    await _reload();
  }

  Future<void> deleteBooks(Iterable<String> bookUids) async {
    final ids = bookUids.toSet();
    if (ids.isEmpty) {
      return;
    }
    for (final uid in ids) {
      await _collectionRepository.removeBookFromAllCollections(uid);
      await _bookRepository.deleteBook(uid);
    }
    state = state.copyWith(selectedBookUids: <String>{});
    await _reload();
  }

  Future<void> moveBooksToCollection({
    required Iterable<String> bookUids,
    required int collectionId,
  }) async {
    final ids = bookUids.toSet();
    if (ids.isEmpty) {
      return;
    }
    for (final uid in ids) {
      await _collectionRepository.removeBookFromAllCollections(uid);
      await _collectionRepository.addBookToCollection(collectionId, uid);
    }
    state = state.copyWith(selectedBookUids: <String>{});
    await _reload();
  }

  Future<void> _reload() async {
    final requestId = ++_requestId;
    final sortMode = state.sortMode;
    final filters = state.filters;
    try {
      final nextState = await _queryState(
        sortMode: sortMode,
        filters: filters,
      );
      if (requestId != _requestId) {
        return;
      }
      state = nextState;
    } catch (error) {
      if (requestId != _requestId) {
        return;
      }
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Reload failed: $error',
      );
    }
  }

  Future<MobileLibraryState> _queryState({
    required LibrarySortMode sortMode,
    required LibraryFilters filters,
  }) async {
    final allItems = await _bookRepository.listLibraryIndex(sortMode: sortMode);
    final defaultCollection = await _collectionRepository.ensureCollection(
      CollectionPresets.uncategorizedName,
    );
    var collectionBookUids =
        await _collectionRepository.listCollectionBookUids();
    final uncategorizedBookUids =
        collectionBookUids[defaultCollection.id] ?? const <String>{};
    final assignedBookUids = <String>{
      for (final entry in collectionBookUids.values) ...entry,
    };
    final missingBookUids = allItems
        .map((item) => item.bookUid)
        .where(
          (bookUid) =>
              !assignedBookUids.contains(bookUid) &&
              !uncategorizedBookUids.contains(bookUid),
        )
        .toSet();
    if (missingBookUids.isNotEmpty) {
      for (final bookUid in missingBookUids) {
        await _collectionRepository.addBookToCollection(
          defaultCollection.id,
          bookUid,
        );
      }
      collectionBookUids = await _collectionRepository.listCollectionBookUids();
    }

    final filteredItems = await _bookRepository.listLibraryIndex(
      sortMode: sortMode,
      filters: filters,
    );
    final collections = await _collectionRepository.listCollections();
    return _buildState(
      allItems: allItems,
      filteredItems: filteredItems,
      collections: collections,
      collectionBookUids: collectionBookUids,
      defaultCollectionId: defaultCollection.id,
    );
  }

  MobileLibraryState _buildState({
    required List<LibraryIndexEntry> allItems,
    required List<LibraryIndexEntry> filteredItems,
    required List<Collection> collections,
    required Map<int, Set<String>> collectionBookUids,
    required int defaultCollectionId,
  }) {
    final collectionIds =
        collections.map((collection) => collection.id).toSet();
    final selectedCollectionId =
        collectionIds.contains(state.selectedCollectionId)
            ? state.selectedCollectionId
            : defaultCollectionId;

    final visibleItems = selectedCollectionId == null
        ? filteredItems
        : filteredItems
            .where(
              (item) => (collectionBookUids[selectedCollectionId] ?? const {})
                  .contains(item.bookUid),
            )
            .toList();

    final formats = visibleItems.map((entry) => entry.format).toSet();
    final categories = visibleItems
        .map((entry) => entry.categoryId ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final filteredSelection = state.selectedBookUids
        .where((uid) => visibleItems.any((item) => item.bookUid == uid))
        .toSet();

    return state.copyWith(
      status:
          allItems.isEmpty ? LibraryPageStatus.empty : LibraryPageStatus.normal,
      items: visibleItems,
      availableFormats: formats,
      availableCategories: categories,
      selectedCollectionId: selectedCollectionId,
      defaultCollectionId: defaultCollectionId,
      collections: collections,
      collectionBookUids: collectionBookUids,
      selectedBookUids: filteredSelection,
      isSelectionMode: state.isSelectionMode && filteredSelection.isNotEmpty,
      clearError: true,
    );
  }
}
