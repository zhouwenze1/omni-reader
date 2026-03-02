import '../../models/settings_models.dart';

abstract class SettingsRepository {
  Future<AppSettings> getAppSettings();

  Future<void> saveAppSettings(AppSettings settings);

  Future<ReaderSettings> getReaderSettings();

  Future<void> saveReaderSettings(ReaderSettings settings);

  Future<CloudOptions> getCloudOptions();

  Future<void> saveCloudOptions(CloudOptions options);
}
