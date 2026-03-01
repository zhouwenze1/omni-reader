enum AppLanguage { system, zhHans, zhHant, en, ja, ko }

extension AppLanguageX on AppLanguage {
  String get value {
    switch (this) {
      case AppLanguage.system:
        return 'system';
      case AppLanguage.zhHans:
        return 'zh-Hans';
      case AppLanguage.zhHant:
        return 'zh-Hant';
      case AppLanguage.en:
        return 'en';
      case AppLanguage.ja:
        return 'ja';
      case AppLanguage.ko:
        return 'ko';
    }
  }
}

AppLanguage appLanguageFromValue(Object? value) {
  switch (value?.toString()) {
    case 'zh-Hans':
      return AppLanguage.zhHans;
    case 'zh-Hant':
      return AppLanguage.zhHant;
    case 'en':
      return AppLanguage.en;
    case 'ja':
      return AppLanguage.ja;
    case 'ko':
      return AppLanguage.ko;
    default:
      return AppLanguage.system;
  }
}

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  String get value {
    switch (this) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }
}

AppThemeMode appThemeModeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'light':
      return AppThemeMode.light;
    case 'dark':
      return AppThemeMode.dark;
    default:
      return AppThemeMode.system;
  }
}

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.system,
    this.themeMode = AppThemeMode.system,
    this.autoCheckUpdate = true,
    this.sendAnonymousUsage = false,
    this.updatedAt,
  });

  final AppLanguage language;
  final AppThemeMode themeMode;
  final bool autoCheckUpdate;
  final bool sendAnonymousUsage;
  final DateTime? updatedAt;

  AppSettings copyWith({
    AppLanguage? language,
    AppThemeMode? themeMode,
    bool? autoCheckUpdate,
    bool? sendAnonymousUsage,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
      sendAnonymousUsage: sendAnonymousUsage ?? this.sendAnonymousUsage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'language': language.value,
      'themeMode': themeMode.value,
      'autoCheckUpdate': autoCheckUpdate,
      'sendAnonymousUsage': sendAnonymousUsage,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      language: appLanguageFromValue(json['language']),
      themeMode: appThemeModeFromValue(json['themeMode']),
      autoCheckUpdate: _asBool(json['autoCheckUpdate']) ?? true,
      sendAnonymousUsage: _asBool(json['sendAnonymousUsage']) ?? false,
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
