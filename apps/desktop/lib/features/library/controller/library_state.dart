import 'package:foundation_domain/domain.dart';

enum LibraryPageStatus { loading, empty, error, normal }

class DesktopLibraryState {
  const DesktopLibraryState({
    required this.status,
    required this.items,
    required this.filteredItems,
    required this.viewMode,
    required this.sortMode,
    required this.filters,
    required this.selectedBookUid,
    required this.selectedCollectionId,
    required this.defaultCollectionId,
    required this.collections,
    required this.collectionBookUids,
    required this.isFilterPanelVisible,
    required this.availableFormats,
    required this.availableCategories,
    required this.isSelectionMode,
    required this.selectedBookUids,
    this.errorMessage,
  });

  const DesktopLibraryState.initial()
      : status = LibraryPageStatus.loading,
        items = const <LibraryIndexEntry>[],
        filteredItems = const <LibraryIndexEntry>[],
        viewMode = LibraryViewMode.grid,
        sortMode = LibrarySortMode.recentRead,
        filters = const LibraryFilters(),
        selectedBookUid = null,
        selectedCollectionId = null,
        defaultCollectionId = null,
        collections = const <Collection>[],
        collectionBookUids = const <int, Set<String>>{},
        isFilterPanelVisible = true,
        availableFormats = const <String>{},
        availableCategories = const <String>{},
        isSelectionMode = false,
        selectedBookUids = const <String>{},
        errorMessage = null;

  final LibraryPageStatus status;
  final List<LibraryIndexEntry> items;
  final List<LibraryIndexEntry> filteredItems;
  final LibraryViewMode viewMode;
  final LibrarySortMode sortMode;
  final LibraryFilters filters;
  final String? selectedBookUid;
  final int? selectedCollectionId;
  final int? defaultCollectionId;
  final List<Collection> collections;
  final Map<int, Set<String>> collectionBookUids;
  final bool isFilterPanelVisible;
  final Set<String> availableFormats;
  final Set<String> availableCategories;
  final bool isSelectionMode;
  final Set<String> selectedBookUids;
  final String? errorMessage;

  LibraryIndexEntry? get selectedItem {
    final uid = selectedBookUid;
    if (uid == null) {
      return null;
    }
    for (final item in filteredItems) {
      if (item.bookUid == uid) {
        return item;
      }
    }
    return null;
  }

  Set<int> collectionsOfBook(String bookUid) {
    final ids = <int>{};
    for (final entry in collectionBookUids.entries) {
      if (entry.value.contains(bookUid)) {
        ids.add(entry.key);
      }
    }
    return ids;
  }

  DesktopLibraryState copyWith({
    LibraryPageStatus? status,
    List<LibraryIndexEntry>? items,
    List<LibraryIndexEntry>? filteredItems,
    LibraryViewMode? viewMode,
    LibrarySortMode? sortMode,
    LibraryFilters? filters,
    String? selectedBookUid,
    int? selectedCollectionId,
    int? defaultCollectionId,
    List<Collection>? collections,
    Map<int, Set<String>>? collectionBookUids,
    bool? isFilterPanelVisible,
    Set<String>? availableFormats,
    Set<String>? availableCategories,
    bool? isSelectionMode,
    Set<String>? selectedBookUids,
    String? errorMessage,
    bool clearError = false,
    bool clearSelectedCollection = false,
  }) {
    return DesktopLibraryState(
      status: status ?? this.status,
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      viewMode: viewMode ?? this.viewMode,
      sortMode: sortMode ?? this.sortMode,
      filters: filters ?? this.filters,
      selectedBookUid: selectedBookUid ?? this.selectedBookUid,
      selectedCollectionId: clearSelectedCollection
          ? null
          : (selectedCollectionId ?? this.selectedCollectionId),
      defaultCollectionId: defaultCollectionId ?? this.defaultCollectionId,
      collections: collections ?? this.collections,
      collectionBookUids: collectionBookUids ?? this.collectionBookUids,
      isFilterPanelVisible: isFilterPanelVisible ?? this.isFilterPanelVisible,
      availableFormats: availableFormats ?? this.availableFormats,
      availableCategories: availableCategories ?? this.availableCategories,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedBookUids: selectedBookUids ?? this.selectedBookUids,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
