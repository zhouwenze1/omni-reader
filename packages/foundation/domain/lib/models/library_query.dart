enum LibraryViewMode { grid, list }

enum LibrarySortMode { recentRead, importedAt, name }

enum LibraryProgressBucket { all, notStarted, inProgress, completed }

const double libraryProgressStartedThreshold = 0.0001;
const double libraryProgressCompletedThreshold = 0.98;

class LibraryFilters {
  const LibraryFilters({
    this.formats = const <String>{},
    this.progress = LibraryProgressBucket.all,
    this.categoryIds = const <String>{},
  });

  final Set<String> formats;
  final LibraryProgressBucket progress;
  final Set<String> categoryIds;

  bool get hasFormatFilter => formats.isNotEmpty;
  bool get hasCategoryFilter => categoryIds.isNotEmpty;
  bool get hasProgressFilter => progress != LibraryProgressBucket.all;
  bool get hasAnyFilter =>
      hasFormatFilter || hasCategoryFilter || hasProgressFilter;
}
