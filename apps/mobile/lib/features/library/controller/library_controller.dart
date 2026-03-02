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

  Future<void> load() async {
    state = state.copyWith(status: LibraryPageStatus.loading, clearError: true);
    try {
      final items = await _bookRepository.listLibraryIndex(
        sortMode: state.sortMode,
        filters: state.filters,
      );
      state = _buildState(items);
    } catch (error) {
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
    try {
      final items = await _bookRepository.listLibraryIndex(
        sortMode: state.sortMode,
        filters: state.filters,
      );
      state = _buildState(items);
    } catch (error) {
      state = state.copyWith(
        status: LibraryPageStatus.error,
        errorMessage: 'Reload failed: $error',
      );
    }
  }

  MobileLibraryState _buildState(List<LibraryIndexEntry> items) {
    final formats = items.map((e) => e.format).toSet();
    final categories = items
        .map((e) => e.categoryId ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
    return state.copyWith(
      status: items.isEmpty ? LibraryPageStatus.empty : LibraryPageStatus.normal,
      items: items,
      availableFormats: formats,
      availableCategories: categories,
      clearError: true,
    );
  }
}
