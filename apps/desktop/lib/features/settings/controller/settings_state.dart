import 'package:foundation_domain/domain.dart';

class SettingsState {
  const SettingsState({
    required this.isLoading,
    required this.app,
    required this.reader,
    required this.cloud,
    this.errorMessage,
  });

  const SettingsState.initial()
      : isLoading = true,
        app = const AppSettings(),
        reader = const ReaderSettings(),
        cloud = const CloudOptions(),
        errorMessage = null;

  final bool isLoading;
  final AppSettings app;
  final ReaderSettings reader;
  final CloudOptions cloud;
  final String? errorMessage;

  SettingsState copyWith({
    bool? isLoading,
    AppSettings? app,
    ReaderSettings? reader,
    CloudOptions? cloud,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      app: app ?? this.app,
      reader: reader ?? this.reader,
      cloud: cloud ?? this.cloud,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
