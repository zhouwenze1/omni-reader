import 'package:foundation_domain/domain.dart';

enum LibraryPageStatus { loading, empty, error, normal }

class MobileLibraryState {
  const MobileLibraryState({
    required this.status,
    required this.items,
    required this.viewMode,
    required this.sortMode,
    required this.filters,
    required this.availableFormats,
    required this.availableCategories,
    required this.selectedCollectionId,
    required this.defaultCollectionId,
    required this.collections,
    required this.collectionBookUids,
    required this.isSelectionMode,
    required this.selectedBookUids,
    this.errorMessage,
  });

  const MobileLibraryState.initial()
      : status = LibraryPageStatus.loading,
        items = const <LibraryIndexEntry>[],
        viewMode = LibraryViewMode.grid,
        sortMode = LibrarySortMode.recentRead,
        filters = const LibraryFilters(),
        availableFormats = const <String>{},
        availableCategories = const <String>{},
        selectedCollectionId = null,
        defaultCollectionId = null,
        collections = const <Collection>[],
        collectionBookUids = const <int, Set<String>>{},
        isSelectionMode = false,
        selectedBookUids = const <String>{},
        errorMessage = null;

  final LibraryPageStatus status;
  final List<LibraryIndexEntry> items;
  final LibraryViewMode viewMode;
  final LibrarySortMode sortMode;
  final LibraryFilters filters;
  final Set<String> availableFormats;
  final Set<String> availableCategories;
  final int? selectedCollectionId;
  final int? defaultCollectionId;
  final List<Collection> collections;
  final Map<int, Set<String>> collectionBookUids;
  final bool isSelectionMode;
  final Set<String> selectedBookUids;
  final String? errorMessage;

  Set<int> collectionsOfBook(String bookUid) {
    final ids = <int>{};
    for (final entry in collectionBookUids.entries) {
      if (entry.value.contains(bookUid)) {
        ids.add(entry.key);
      }
    }
    return ids;
  }

  MobileLibraryState copyWith({
    LibraryPageStatus? status,
    List<LibraryIndexEntry>? items,
    LibraryViewMode? viewMode,
    LibrarySortMode? sortMode,
    LibraryFilters? filters,
    Set<String>? availableFormats,
    Set<String>? availableCategories,
    int? selectedCollectionId,
    int? defaultCollectionId,
    List<Collection>? collections,
    Map<int, Set<String>>? collectionBookUids,
    bool? isSelectionMode,
    Set<String>? selectedBookUids,
    String? errorMessage,
    bool clearError = false,
    bool clearSelectedCollection = false,
  }) {
    return MobileLibraryState(
      status: status ?? this.status,
      items: items ?? this.items,
      viewMode: viewMode ?? this.viewMode,
      sortMode: sortMode ?? this.sortMode,
      filters: filters ?? this.filters,
      availableFormats: availableFormats ?? this.availableFormats,
      availableCategories: availableCategories ?? this.availableCategories,
      selectedCollectionId: clearSelectedCollection
          ? null
          : (selectedCollectionId ?? this.selectedCollectionId),
      defaultCollectionId: defaultCollectionId ?? this.defaultCollectionId,
      collections: collections ?? this.collections,
      collectionBookUids: collectionBookUids ?? this.collectionBookUids,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedBookUids: selectedBookUids ?? this.selectedBookUids,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
