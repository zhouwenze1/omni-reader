import 'package:foundation_domain/domain.dart';

class ReadingNowState {
  const ReadingNowState({
    required this.isLoading,
    required this.items,
    this.errorMessage,
  });

  const ReadingNowState.initial()
      : isLoading = true,
        items = const <LibraryIndexEntry>[],
        errorMessage = null;

  final bool isLoading;
  final List<LibraryIndexEntry> items;
  final String? errorMessage;

  ReadingNowState copyWith({
    bool? isLoading,
    List<LibraryIndexEntry>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReadingNowState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
