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
        errorMessage = null;

  final LibraryPageStatus status;
  final List<LibraryIndexEntry> items;
  final LibraryViewMode viewMode;
  final LibrarySortMode sortMode;
  final LibraryFilters filters;
  final Set<String> availableFormats;
  final Set<String> availableCategories;
  final String? errorMessage;

  MobileLibraryState copyWith({
    LibraryPageStatus? status,
    List<LibraryIndexEntry>? items,
    LibraryViewMode? viewMode,
    LibrarySortMode? sortMode,
    LibraryFilters? filters,
    Set<String>? availableFormats,
    Set<String>? availableCategories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MobileLibraryState(
      status: status ?? this.status,
      items: items ?? this.items,
      viewMode: viewMode ?? this.viewMode,
      sortMode: sortMode ?? this.sortMode,
      filters: filters ?? this.filters,
      availableFormats: availableFormats ?? this.availableFormats,
      availableCategories: availableCategories ?? this.availableCategories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
