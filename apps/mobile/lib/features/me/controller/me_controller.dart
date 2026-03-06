import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'me_state.dart';

final meControllerProvider = StateNotifierProvider<MeController, MeState>((
  ref,
) {
  final controller = MeController(
    bookRepository: ref.watch(bookRepositoryProvider),
    annotationRepository: ref.watch(annotationRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

class MeController extends StateNotifier<MeState> {
  MeController({
    required BookRepository bookRepository,
    required AnnotationRepository annotationRepository,
  })  : _bookRepository = bookRepository,
        _annotationRepository = annotationRepository,
        super(const MeState.initial());

  final BookRepository _bookRepository;
  final AnnotationRepository _annotationRepository;

  Future<void> load() async {
    state = state.copyWith(status: MePageStatus.loading, clearError: true);
    try {
      final items = await _bookRepository.listLibraryIndex(
        sortMode: LibrarySortMode.recentRead,
      );
      final now = DateTime.now();
      final recentThreshold = now.subtract(const Duration(days: 7));

      var inProgressBooks = 0;
      var completedBooks = 0;
      var notStartedBooks = 0;
      var booksOpenedInLast7Days = 0;
      var booksImportedInLast7Days = 0;
      var progressSum = 0.0;
      DateTime? latestOpenedAt;

      for (final item in items) {
        final progress = (item.cachedProgress ?? 0).clamp(0.0, 1.0);
        progressSum += progress;
        if (progress >= 0.98) {
          completedBooks += 1;
        } else if (progress <= 0.0001) {
          notStartedBooks += 1;
        } else {
          inProgressBooks += 1;
        }

        final openedAt = item.lastOpenedAt;
        if (openedAt != null) {
          if (openedAt.isAfter(recentThreshold)) {
            booksOpenedInLast7Days += 1;
          }
          if (latestOpenedAt == null || openedAt.isAfter(latestOpenedAt)) {
            latestOpenedAt = openedAt;
          }
        }

        if (item.importedAt.isAfter(recentThreshold)) {
          booksImportedInLast7Days += 1;
        }
      }

      final counters = await _countAnnotations(items);
      state = state.copyWith(
        status: MePageStatus.ready,
        totalBooks: items.length,
        inProgressBooks: inProgressBooks,
        completedBooks: completedBooks,
        notStartedBooks: notStartedBooks,
        averageProgress: items.isEmpty ? 0 : (progressSum / items.length),
        booksOpenedInLast7Days: booksOpenedInLast7Days,
        booksImportedInLast7Days: booksImportedInLast7Days,
        highlightsCount: counters.highlights,
        notesCount: counters.notes,
        bookmarksCount: counters.bookmarks,
        recentBooks: items.take(5).toList(),
        latestOpenedAt: latestOpenedAt,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: MePageStatus.error,
        errorMessage: '加载统计失败: $error',
      );
    }
  }

  Future<void> refresh() => load();

  Future<_AnnotationCounters> _countAnnotations(
    List<LibraryIndexEntry> items,
  ) async {
    var highlights = 0;
    var notes = 0;
    var bookmarks = 0;

    for (final item in items) {
      try {
        final annotations = await _annotationRepository.listAnnotations(
          item.bookUid,
        );
        for (final annotation in annotations) {
          switch (annotation.type) {
            case AnnotationType.highlight:
              highlights += 1;
            case AnnotationType.note:
              notes += 1;
            case AnnotationType.bookmark:
              bookmarks += 1;
          }
        }
      } catch (_) {
        // Keep page usable when a single book's annotation file is broken.
      }
    }

    return _AnnotationCounters(
      highlights: highlights,
      notes: notes,
      bookmarks: bookmarks,
    );
  }
}

class _AnnotationCounters {
  const _AnnotationCounters({
    required this.highlights,
    required this.notes,
    required this.bookmarks,
  });

  final int highlights;
  final int notes;
  final int bookmarks;
}
