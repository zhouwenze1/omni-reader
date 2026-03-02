class AppSettings {
  const AppSettings({this.locale = 'system', this.debugImport = false});

  final String locale;
  final bool debugImport;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      locale: (json['locale'] as String?) ?? 'system',
      debugImport: (json['debugImport'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'locale': locale, 'debugImport': debugImport};
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.theme = 'light',
  });

  final double fontSize;
  final double lineHeight;
  final String theme;

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      theme: (json['theme'] as String?) ?? 'light',
    );
  }

  Map<String, dynamic> toJson() {
    return {'fontSize': fontSize, 'lineHeight': lineHeight, 'theme': theme};
  }
}

class CloudOptions {
  const CloudOptions({this.provider = 'none', this.autoSync = false});

  final String provider;
  final bool autoSync;

  factory CloudOptions.fromJson(Map<String, dynamic> json) {
    return CloudOptions(
      provider: (json['provider'] as String?) ?? 'none',
      autoSync: (json['autoSync'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'provider': provider, 'autoSync': autoSync};
  }
}
