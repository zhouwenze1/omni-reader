import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'library_state.dart';

final mobileLibraryControllerProvider =
    StateNotifierProvider<MobileLibraryController, MobileLibraryState>((ref) {
  final controller = MobileLibraryController(
    bookRepository: ref.watch(bookRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

class MobileLibraryController extends StateNotifier<MobileLibraryState> {
  MobileLibraryController({required BookRepository bookRepository})
      : _bookRepository = bookRepository,
        super(const MobileLibraryState.initial());

  final BookRepository _bookRepository;
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

  Future<void> deleteBook(String bookUid) async {
    await _bookRepository.deleteBook(bookUid);
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
    final items = await _bookRepository.listLibraryIndex(
      sortMode: sortMode,
      filters: filters,
    );
    return _buildState(items, allItems);
  }

  MobileLibraryState _buildState(
    List<LibraryIndexEntry> items,
    List<LibraryIndexEntry> allItems,
  ) {
    final formats = allItems.map((e) => e.format).toSet();
    final categories = allItems
        .map((e) => e.categoryId ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
    return state.copyWith(
      status:
          allItems.isEmpty ? LibraryPageStatus.empty : LibraryPageStatus.normal,
      items: items,
      availableFormats: formats,
      availableCategories: categories,
      clearError: true,
    );
  }
}
