class ReaderUiState {
  const ReaderUiState({
    this.progress = 0,
    this.chromeVisible = true,
  });

  final double progress;
  final bool chromeVisible;

  ReaderUiState copyWith({
    double? progress,
    bool? chromeVisible,
  }) {
    return ReaderUiState(
      progress: progress ?? this.progress,
      chromeVisible: chromeVisible ?? this.chromeVisible,
    );
  }
}
