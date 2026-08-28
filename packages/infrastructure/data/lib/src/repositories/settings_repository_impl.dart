import 'package:foundation_domain/domain.dart';
import 'package:hive/hive.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._box);

  static const String appSettingsKey = 'settings.app.v1';
  static const String readerSettingsKey = 'settings.reader.v2';
  static const String legacyReaderSettingsKey = 'settings.reader.v1';
  static const String cloudSettingsKey = 'settings.cloud.v1';

  final Box<dynamic> _box;

  @override
  Future<AppSettings> getAppSettings() async {
    final raw = _box.get(appSettingsKey);
    if (raw is Map) {
      return AppSettings.fromJson(raw.map((k, v) => MapEntry('$k', v)));
    }
    return const AppSettings();
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) {
    return _box.put(appSettingsKey, settings.toJson());
  }

  @override
  Future<ReaderSettings> getReaderSettings() async {
    final raw = _box.get(readerSettingsKey);
    if (raw is Map) {
      return ReaderSettings.fromJson(raw.map((k, v) => MapEntry('$k', v)));
    }

    final legacyRaw = _box.get(legacyReaderSettingsKey);
    if (legacyRaw is Map) {
      final legacyJson = legacyRaw.map((k, v) => MapEntry('$k', v));
      final legacySettings = ReaderSettings.fromJson(legacyJson);
      final legacyLayoutMode = legacyJson['layoutMode']?.toString().trim();
      final migratedLayoutMode = legacyLayoutMode == null ||
              legacyLayoutMode.isEmpty ||
              legacyLayoutMode.toLowerCase() == 'paged_spread'
          ? ReaderLayoutMode.pagedAuto
          : ReaderLayoutMode.normalize(legacyLayoutMode);
      final migratedSettings = legacySettings.copyWith(
        layoutMode: migratedLayoutMode,
      );
      await saveReaderSettings(migratedSettings);
      return migratedSettings;
    }

    return const ReaderSettings();
  }

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) {
    return _box.put(readerSettingsKey, settings.toJson());
  }

  @override
  Future<CloudOptions> getCloudOptions() async {
    final raw = _box.get(cloudSettingsKey);
    if (raw is Map) {
      return CloudOptions.fromJson(raw.map((k, v) => MapEntry('$k', v)));
    }
    return const CloudOptions();
  }

  @override
  Future<void> saveCloudOptions(CloudOptions options) {
    return _box.put(cloudSettingsKey, options.toJson());
  }
}
