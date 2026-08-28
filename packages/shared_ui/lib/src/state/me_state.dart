import 'package:foundation_domain/domain.dart';

enum MePageStatus { loading, ready, error }

class MeState {
  const MeState({
    required this.status,
    required this.totalBooks,
    required this.inProgressBooks,
    required this.completedBooks,
    required this.notStartedBooks,
    required this.averageProgress,
    required this.booksOpenedInLast7Days,
    required this.booksImportedInLast7Days,
    required this.highlightsCount,
    required this.notesCount,
    required this.bookmarksCount,
    required this.recentBooks,
    this.latestOpenedAt,
    this.errorMessage,
  });

  const MeState.initial()
      : status = MePageStatus.loading,
        totalBooks = 0,
        inProgressBooks = 0,
        completedBooks = 0,
        notStartedBooks = 0,
        averageProgress = 0,
        booksOpenedInLast7Days = 0,
        booksImportedInLast7Days = 0,
        highlightsCount = 0,
        notesCount = 0,
        bookmarksCount = 0,
        recentBooks = const <LibraryIndexEntry>[],
        latestOpenedAt = null,
        errorMessage = null;

  final MePageStatus status;
  final int totalBooks;
  final int inProgressBooks;
  final int completedBooks;
  final int notStartedBooks;
  final double averageProgress;
  final int booksOpenedInLast7Days;
  final int booksImportedInLast7Days;
  final int highlightsCount;
  final int notesCount;
  final int bookmarksCount;
  final List<LibraryIndexEntry> recentBooks;
  final DateTime? latestOpenedAt;
  final String? errorMessage;

  int get annotationsCount => highlightsCount + notesCount + bookmarksCount;

  MeState copyWith({
    MePageStatus? status,
    int? totalBooks,
    int? inProgressBooks,
    int? completedBooks,
    int? notStartedBooks,
    double? averageProgress,
    int? booksOpenedInLast7Days,
    int? booksImportedInLast7Days,
    int? highlightsCount,
    int? notesCount,
    int? bookmarksCount,
    List<LibraryIndexEntry>? recentBooks,
    DateTime? latestOpenedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MeState(
      status: status ?? this.status,
      totalBooks: totalBooks ?? this.totalBooks,
      inProgressBooks: inProgressBooks ?? this.inProgressBooks,
      completedBooks: completedBooks ?? this.completedBooks,
      notStartedBooks: notStartedBooks ?? this.notStartedBooks,
      averageProgress: averageProgress ?? this.averageProgress,
      booksOpenedInLast7Days:
          booksOpenedInLast7Days ?? this.booksOpenedInLast7Days,
      booksImportedInLast7Days:
          booksImportedInLast7Days ?? this.booksImportedInLast7Days,
      highlightsCount: highlightsCount ?? this.highlightsCount,
      notesCount: notesCount ?? this.notesCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      recentBooks: recentBooks ?? this.recentBooks,
      latestOpenedAt: latestOpenedAt ?? this.latestOpenedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
