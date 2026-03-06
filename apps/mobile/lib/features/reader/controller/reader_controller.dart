import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reader_state.dart';

class ReaderController extends StateNotifier<ReaderUiState> {
  ReaderController() : super(const ReaderUiState());

  void setProgress(double value) {
    state = state.copyWith(progress: value.clamp(0, 1));
  }

  void toggleChrome() {
    state = state.copyWith(chromeVisible: !state.chromeVisible);
  }
}
