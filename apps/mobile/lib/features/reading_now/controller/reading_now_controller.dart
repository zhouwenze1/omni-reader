import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'reading_now_state.dart';

final readingNowControllerProvider =
    StateNotifierProvider<ReadingNowController, ReadingNowState>((ref) {
  final controller = ReadingNowController(
    bookRepository: ref.watch(bookRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

class ReadingNowController extends StateNotifier<ReadingNowState> {
  ReadingNowController({required BookRepository bookRepository})
      : _bookRepository = bookRepository,
        super(const ReadingNowState.initial());

  final BookRepository _bookRepository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _bookRepository.listLibraryIndex(
        sortMode: LibrarySortMode.recentRead,
      );
      state = state.copyWith(isLoading: false, items: items, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载阅读中失败: $error',
      );
    }
  }
}
