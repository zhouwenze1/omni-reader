import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'settings_state.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  final controller = SettingsController(
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository,
        super(const SettingsState.initial());

  final SettingsRepository _settingsRepository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _settingsRepository.getAppSettings(),
        _settingsRepository.getReaderSettings(),
        _settingsRepository.getCloudOptions(),
      ]);
      state = state.copyWith(
        isLoading: false,
        app: results[0] as AppSettings,
        reader: results[1] as ReaderSettings,
        cloud: results[2] as CloudOptions,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载设置失败: $error',
      );
    }
  }

  Future<void> updateApp(AppSettings next) async {
    final previous = state;
    state = state.copyWith(app: next, clearError: true);
    try {
      await _settingsRepository.saveAppSettings(next);
    } catch (error) {
      state = previous.copyWith(errorMessage: '保存应用设置失败: $error');
    }
  }

  Future<void> updateReader(ReaderSettings next) async {
    final previous = state;
    state = state.copyWith(reader: next, clearError: true);
    try {
      await _settingsRepository.saveReaderSettings(next);
    } catch (error) {
      state = previous.copyWith(errorMessage: '保存阅读器设置失败: $error');
    }
  }

  Future<void> updateCloud(CloudOptions next) async {
    final previous = state;
    state = state.copyWith(cloud: next, clearError: true);
    try {
      await _settingsRepository.saveCloudOptions(next);
    } catch (error) {
      state = previous.copyWith(errorMessage: '保存云设置失败: $error');
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) {
    return updateApp(state.app.copyWith(themeMode: mode));
  }

  Future<void> setLocale(String locale) {
    return updateApp(state.app.copyWith(locale: locale));
  }

  Future<void> setDebugImport(bool enabled) {
    return updateApp(state.app.copyWith(debugImport: enabled));
  }
}
