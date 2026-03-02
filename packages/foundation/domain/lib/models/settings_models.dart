enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    this.locale = 'system',
    this.themeMode = AppThemeMode.system,
    this.debugImport = false,
    this.autoCheckUpdate = true,
    this.sendAnonymousUsage = false,
  });

  final String locale;
  final AppThemeMode themeMode;
  final bool debugImport;
  final bool autoCheckUpdate;
  final bool sendAnonymousUsage;

  AppSettings copyWith({
    String? locale,
    AppThemeMode? themeMode,
    bool? debugImport,
    bool? autoCheckUpdate,
    bool? sendAnonymousUsage,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      debugImport: debugImport ?? this.debugImport,
      autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
      sendAnonymousUsage: sendAnonymousUsage ?? this.sendAnonymousUsage,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeRaw = (json['themeMode'] ?? json['theme'])?.toString();
    return AppSettings(
      locale: (json['locale'] as String?) ?? 'system',
      themeMode: _themeModeFromString(themeRaw),
      debugImport: _asBool(json['debugImport']) ?? false,
      autoCheckUpdate: _asBool(json['autoCheckUpdate']) ?? true,
      sendAnonymousUsage: _asBool(json['sendAnonymousUsage']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locale': locale,
      'themeMode': themeMode.name,
      'debugImport': debugImport,
      'autoCheckUpdate': autoCheckUpdate,
      'sendAnonymousUsage': sendAnonymousUsage,
    };
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.fontFamily = 'system',
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.pageGap = 24,
    this.paddingHorizontal = 36,
    this.paddingVertical = 16,
    this.textIndentEnabled = true,
    this.textIndentEm = 2,
    this.textIndentSkipFirstParagraph = false,
    this.theme = 'day',
    this.layoutMode = 'paged_spread',
    this.progressDisplay = 'percentage',
  });

  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double pageGap;
  final double paddingHorizontal;
  final double paddingVertical;
  final bool textIndentEnabled;
  final double textIndentEm;
  final bool textIndentSkipFirstParagraph;
  final String theme;
  final String layoutMode;
  final String progressDisplay;

  ReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? pageGap,
    double? paddingHorizontal,
    double? paddingVertical,
    bool? textIndentEnabled,
    double? textIndentEm,
    bool? textIndentSkipFirstParagraph,
    String? theme,
    String? layoutMode,
    String? progressDisplay,
  }) {
    return ReaderSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      pageGap: pageGap ?? this.pageGap,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      paddingVertical: paddingVertical ?? this.paddingVertical,
      textIndentEnabled: textIndentEnabled ?? this.textIndentEnabled,
      textIndentEm: textIndentEm ?? this.textIndentEm,
      textIndentSkipFirstParagraph:
          textIndentSkipFirstParagraph ?? this.textIndentSkipFirstParagraph,
      theme: theme ?? this.theme,
      layoutMode: layoutMode ?? this.layoutMode,
      progressDisplay: progressDisplay ?? this.progressDisplay,
    );
  }

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontFamily: (json['fontFamily'] as String?) ?? 'system',
      fontSize: _asDouble(json['fontSize']) ?? 18,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.6,
      pageGap: _asDouble(json['pageGap']) ?? 24,
      paddingHorizontal: _asDouble(
            json['paddingHorizontal'] ?? json['paddingRight'],
          ) ??
          36,
      paddingVertical: _asDouble(json['paddingVertical'] ?? json['paddingTop']) ??
          16,
      textIndentEnabled: _asBool(json['textIndentEnabled']) ?? true,
      textIndentEm: _asDouble(json['textIndentEm']) ?? 2,
      textIndentSkipFirstParagraph:
          _asBool(json['textIndentSkipFirstParagraph']) ?? false,
      theme: (json['theme'] as String?) ?? 'day',
      layoutMode: (json['layoutMode'] as String?) ?? 'paged_spread',
      progressDisplay: (json['progressDisplay'] as String?) ?? 'percentage',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'pageGap': pageGap,
      'paddingHorizontal': paddingHorizontal,
      'paddingVertical': paddingVertical,
      'textIndentEnabled': textIndentEnabled,
      'textIndentEm': textIndentEm,
      'textIndentSkipFirstParagraph': textIndentSkipFirstParagraph,
      'theme': theme,
      'layoutMode': layoutMode,
      'progressDisplay': progressDisplay,
    };
  }
}

class CloudOptions {
  const CloudOptions({
    this.provider = 'none',
    this.autoSync = false,
    this.storeOriginalFiles = false,
    this.storeProgress = true,
    this.storeNotes = true,
    this.storeHighlights = true,
    this.storeAppData = false,
  });

  final String provider;
  final bool autoSync;
  final bool storeOriginalFiles;
  final bool storeProgress;
  final bool storeNotes;
  final bool storeHighlights;
  final bool storeAppData;

  CloudOptions copyWith({
    String? provider,
    bool? autoSync,
    bool? storeOriginalFiles,
    bool? storeProgress,
    bool? storeNotes,
    bool? storeHighlights,
    bool? storeAppData,
  }) {
    return CloudOptions(
      provider: provider ?? this.provider,
      autoSync: autoSync ?? this.autoSync,
      storeOriginalFiles: storeOriginalFiles ?? this.storeOriginalFiles,
      storeProgress: storeProgress ?? this.storeProgress,
      storeNotes: storeNotes ?? this.storeNotes,
      storeHighlights: storeHighlights ?? this.storeHighlights,
      storeAppData: storeAppData ?? this.storeAppData,
    );
  }

  factory CloudOptions.fromJson(Map<String, dynamic> json) {
    return CloudOptions(
      provider: (json['provider'] as String?) ?? 'none',
      autoSync: _asBool(json['autoSync']) ?? false,
      storeOriginalFiles: _asBool(json['storeOriginalFiles']) ?? false,
      storeProgress: _asBool(json['storeProgress']) ?? true,
      storeNotes: _asBool(json['storeNotes']) ?? true,
      storeHighlights: _asBool(json['storeHighlights']) ?? true,
      storeAppData: _asBool(json['storeAppData']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'provider': provider,
      'autoSync': autoSync,
      'storeOriginalFiles': storeOriginalFiles,
      'storeProgress': storeProgress,
      'storeNotes': storeNotes,
      'storeHighlights': storeHighlights,
      'storeAppData': storeAppData,
    };
  }
}

AppThemeMode _themeModeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'light':
      return AppThemeMode.light;
    case 'dark':
      return AppThemeMode.dark;
    default:
      return AppThemeMode.system;
  }
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == '1') {
      return true;
    }
    if (text == 'false' || text == '0') {
      return false;
    }
  }
  return null;
}
