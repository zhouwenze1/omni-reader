enum TranslationProvider { none, baidu, google, deepl }

extension TranslationProviderX on TranslationProvider {
  String get value {
    switch (this) {
      case TranslationProvider.none:
        return 'none';
      case TranslationProvider.baidu:
        return 'baidu';
      case TranslationProvider.google:
        return 'google';
      case TranslationProvider.deepl:
        return 'deepl';
    }
  }
}

TranslationProvider translationProviderFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'baidu':
      return TranslationProvider.baidu;
    case 'google':
      return TranslationProvider.google;
    case 'deepl':
      return TranslationProvider.deepl;
    default:
      return TranslationProvider.none;
  }
}

enum DictionaryProvider { none, youdao, bing }

extension DictionaryProviderX on DictionaryProvider {
  String get value {
    switch (this) {
      case DictionaryProvider.none:
        return 'none';
      case DictionaryProvider.youdao:
        return 'youdao';
      case DictionaryProvider.bing:
        return 'bing';
    }
  }
}

DictionaryProvider dictionaryProviderFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'youdao':
      return DictionaryProvider.youdao;
    case 'bing':
      return DictionaryProvider.bing;
    default:
      return DictionaryProvider.none;
  }
}

enum TtsProvider { none, system, google, azure }

extension TtsProviderX on TtsProvider {
  String get value {
    switch (this) {
      case TtsProvider.none:
        return 'none';
      case TtsProvider.system:
        return 'system';
      case TtsProvider.google:
        return 'google';
      case TtsProvider.azure:
        return 'azure';
    }
  }
}

TtsProvider ttsProviderFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'system':
      return TtsProvider.system;
    case 'google':
      return TtsProvider.google;
    case 'azure':
      return TtsProvider.azure;
    default:
      return TtsProvider.none;
  }
}

class ReadingAssistSettings {
  const ReadingAssistSettings({
    this.translationProvider = TranslationProvider.none,
    this.dictionaryProvider = DictionaryProvider.none,
    this.ttsProvider = TtsProvider.system,
    this.autoTranslateSelection = false,
    this.autoSpeakSelection = false,
    this.showDictionaryPopup = true,
    this.ttsSpeed = 1,
    this.ttsPitch = 1,
    this.updatedAt,
  });

  final TranslationProvider translationProvider;
  final DictionaryProvider dictionaryProvider;
  final TtsProvider ttsProvider;
  final bool autoTranslateSelection;
  final bool autoSpeakSelection;
  final bool showDictionaryPopup;
  final double ttsSpeed;
  final double ttsPitch;
  final DateTime? updatedAt;

  ReadingAssistSettings copyWith({
    TranslationProvider? translationProvider,
    DictionaryProvider? dictionaryProvider,
    TtsProvider? ttsProvider,
    bool? autoTranslateSelection,
    bool? autoSpeakSelection,
    bool? showDictionaryPopup,
    double? ttsSpeed,
    double? ttsPitch,
    DateTime? updatedAt,
  }) {
    return ReadingAssistSettings(
      translationProvider: translationProvider ?? this.translationProvider,
      dictionaryProvider: dictionaryProvider ?? this.dictionaryProvider,
      ttsProvider: ttsProvider ?? this.ttsProvider,
      autoTranslateSelection:
          autoTranslateSelection ?? this.autoTranslateSelection,
      autoSpeakSelection: autoSpeakSelection ?? this.autoSpeakSelection,
      showDictionaryPopup: showDictionaryPopup ?? this.showDictionaryPopup,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'translationProvider': translationProvider.value,
      'dictionaryProvider': dictionaryProvider.value,
      'ttsProvider': ttsProvider.value,
      'autoTranslateSelection': autoTranslateSelection,
      'autoSpeakSelection': autoSpeakSelection,
      'showDictionaryPopup': showDictionaryPopup,
      'ttsSpeed': ttsSpeed,
      'ttsPitch': ttsPitch,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ReadingAssistSettings.fromJson(Map<String, Object?> json) {
    return ReadingAssistSettings(
      translationProvider: translationProviderFromValue(
        json['translationProvider'],
      ),
      dictionaryProvider: dictionaryProviderFromValue(
        json['dictionaryProvider'],
      ),
      ttsProvider: ttsProviderFromValue(json['ttsProvider']),
      autoTranslateSelection: _asBool(json['autoTranslateSelection']) ?? false,
      autoSpeakSelection: _asBool(json['autoSpeakSelection']) ?? false,
      showDictionaryPopup: _asBool(json['showDictionaryPopup']) ?? true,
      ttsSpeed: _asDouble(json['ttsSpeed']) ?? 1,
      ttsPitch: _asDouble(json['ttsPitch']) ?? 1,
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

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
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
