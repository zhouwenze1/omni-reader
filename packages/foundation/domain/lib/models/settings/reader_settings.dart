enum ReaderTheme { white, dark, sepia, custom }

extension ReaderThemeX on ReaderTheme {
  String get value {
    switch (this) {
      case ReaderTheme.white:
        return 'white';
      case ReaderTheme.dark:
        return 'dark';
      case ReaderTheme.sepia:
        return 'sepia';
      case ReaderTheme.custom:
        return 'custom';
    }
  }
}

ReaderTheme readerThemeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'dark':
      return ReaderTheme.dark;
    case 'sepia':
      return ReaderTheme.sepia;
    case 'custom':
      return ReaderTheme.custom;
    default:
      return ReaderTheme.white;
  }
}

enum ReaderLayoutMode { scroll, paged }

extension ReaderLayoutModeX on ReaderLayoutMode {
  String get value {
    switch (this) {
      case ReaderLayoutMode.scroll:
        return 'scroll';
      case ReaderLayoutMode.paged:
        return 'paged';
    }
  }
}

ReaderLayoutMode readerLayoutModeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'paged':
      return ReaderLayoutMode.paged;
    default:
      return ReaderLayoutMode.scroll;
  }
}

enum ReaderBrightnessMode { system, manual }

extension ReaderBrightnessModeX on ReaderBrightnessMode {
  String get value {
    switch (this) {
      case ReaderBrightnessMode.system:
        return 'system';
      case ReaderBrightnessMode.manual:
        return 'manual';
    }
  }
}

ReaderBrightnessMode readerBrightnessModeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'manual':
      return ReaderBrightnessMode.manual;
    default:
      return ReaderBrightnessMode.system;
  }
}

enum ReaderTextAlignMode { start, justify }

extension ReaderTextAlignModeX on ReaderTextAlignMode {
  String get value {
    switch (this) {
      case ReaderTextAlignMode.start:
        return 'start';
      case ReaderTextAlignMode.justify:
        return 'justify';
    }
  }
}

ReaderTextAlignMode readerTextAlignModeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'justify':
      return ReaderTextAlignMode.justify;
    default:
      return ReaderTextAlignMode.start;
  }
}

enum ReaderPageTurnAnimation { none, slide, simulation }

extension ReaderPageTurnAnimationX on ReaderPageTurnAnimation {
  String get value {
    switch (this) {
      case ReaderPageTurnAnimation.none:
        return 'none';
      case ReaderPageTurnAnimation.slide:
        return 'slide';
      case ReaderPageTurnAnimation.simulation:
        return 'simulation';
    }
  }
}

ReaderPageTurnAnimation readerPageTurnAnimationFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'slide':
      return ReaderPageTurnAnimation.slide;
    case 'simulation':
      return ReaderPageTurnAnimation.simulation;
    default:
      return ReaderPageTurnAnimation.none;
  }
}

enum ReaderProgressDisplay { percentage, pageNumber, chapter, hidden }

extension ReaderProgressDisplayX on ReaderProgressDisplay {
  String get value {
    switch (this) {
      case ReaderProgressDisplay.percentage:
        return 'percentage';
      case ReaderProgressDisplay.pageNumber:
        return 'page_number';
      case ReaderProgressDisplay.chapter:
        return 'chapter';
      case ReaderProgressDisplay.hidden:
        return 'hidden';
    }
  }
}

ReaderProgressDisplay readerProgressDisplayFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'page_number':
      return ReaderProgressDisplay.pageNumber;
    case 'chapter':
      return ReaderProgressDisplay.chapter;
    case 'hidden':
      return ReaderProgressDisplay.hidden;
    default:
      return ReaderProgressDisplay.percentage;
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 17,
    this.lineHeight = 1.7,
    this.letterSpacing = 0,
    this.paragraphSpacing = 0.5,
    this.edgePadding = 16,
    this.fontFamily = 'Noto Serif SC',
    this.theme = ReaderTheme.white,
    this.layoutMode = ReaderLayoutMode.scroll,
    this.brightnessMode = ReaderBrightnessMode.system,
    this.brightness = 1,
    this.textAlign = ReaderTextAlignMode.start,
    this.pageTurnAnimation = ReaderPageTurnAnimation.simulation,
    this.progressDisplay = ReaderProgressDisplay.percentage,
    this.enableDoublePageInLandscape = true,
    this.pageGap = 24,
    this.gutterWidth = 26,
    this.textIndentEnabled = false,
    this.textIndentEm = 2,
    this.textIndentSkipFirstParagraph = true,
    this.customTextColor,
    this.customBackgroundColor,
    this.customLinkColor,
    this.customSelectionColor,
    this.updatedAt,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double edgePadding;
  final String fontFamily;
  final ReaderTheme theme;
  final ReaderLayoutMode layoutMode;
  final ReaderBrightnessMode brightnessMode;
  final double brightness;
  final ReaderTextAlignMode textAlign;
  final ReaderPageTurnAnimation pageTurnAnimation;
  final ReaderProgressDisplay progressDisplay;
  final bool enableDoublePageInLandscape;
  final double pageGap;
  final double gutterWidth;
  final bool textIndentEnabled;
  final double textIndentEm;
  final bool textIndentSkipFirstParagraph;
  final String? customTextColor;
  final String? customBackgroundColor;
  final String? customLinkColor;
  final String? customSelectionColor;
  final DateTime? updatedAt;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    double? edgePadding,
    String? fontFamily,
    ReaderTheme? theme,
    ReaderLayoutMode? layoutMode,
    ReaderBrightnessMode? brightnessMode,
    double? brightness,
    ReaderTextAlignMode? textAlign,
    ReaderPageTurnAnimation? pageTurnAnimation,
    ReaderProgressDisplay? progressDisplay,
    bool? enableDoublePageInLandscape,
    double? pageGap,
    double? gutterWidth,
    bool? textIndentEnabled,
    double? textIndentEm,
    bool? textIndentSkipFirstParagraph,
    String? customTextColor,
    String? customBackgroundColor,
    String? customLinkColor,
    String? customSelectionColor,
    DateTime? updatedAt,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      edgePadding: edgePadding ?? this.edgePadding,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
      layoutMode: layoutMode ?? this.layoutMode,
      brightnessMode: brightnessMode ?? this.brightnessMode,
      brightness: brightness ?? this.brightness,
      textAlign: textAlign ?? this.textAlign,
      pageTurnAnimation: pageTurnAnimation ?? this.pageTurnAnimation,
      progressDisplay: progressDisplay ?? this.progressDisplay,
      enableDoublePageInLandscape:
          enableDoublePageInLandscape ?? this.enableDoublePageInLandscape,
      pageGap: pageGap ?? this.pageGap,
      gutterWidth: gutterWidth ?? this.gutterWidth,
      textIndentEnabled: textIndentEnabled ?? this.textIndentEnabled,
      textIndentEm: textIndentEm ?? this.textIndentEm,
      textIndentSkipFirstParagraph:
          textIndentSkipFirstParagraph ?? this.textIndentSkipFirstParagraph,
      customTextColor: customTextColor ?? this.customTextColor,
      customBackgroundColor:
          customBackgroundColor ?? this.customBackgroundColor,
      customLinkColor: customLinkColor ?? this.customLinkColor,
      customSelectionColor: customSelectionColor ?? this.customSelectionColor,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'paragraphSpacing': paragraphSpacing,
      'edgePadding': edgePadding,
      'fontFamily': fontFamily,
      'theme': theme.value,
      'layoutMode': layoutMode.value,
      'brightnessMode': brightnessMode.value,
      'brightness': brightness,
      'textAlign': textAlign.value,
      'pageTurnAnimation': pageTurnAnimation.value,
      'progressDisplay': progressDisplay.value,
      'enableDoublePageInLandscape': enableDoublePageInLandscape,
      'pageGap': pageGap,
      'gutterWidth': gutterWidth,
      'textIndentEnabled': textIndentEnabled,
      'textIndentEm': textIndentEm,
      'textIndentSkipFirstParagraph': textIndentSkipFirstParagraph,
      'customTextColor': customTextColor,
      'customBackgroundColor': customBackgroundColor,
      'customLinkColor': customLinkColor,
      'customSelectionColor': customSelectionColor,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ReaderSettings.fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: _asDouble(json['fontSize']) ?? 17,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.7,
      letterSpacing: _asDouble(json['letterSpacing']) ?? 0,
      paragraphSpacing: _asDouble(json['paragraphSpacing']) ?? 0.5,
      edgePadding: _asDouble(json['edgePadding']) ?? 16,
      fontFamily: _asString(json['fontFamily']) ?? 'Noto Serif SC',
      theme: readerThemeFromValue(json['theme']),
      layoutMode: readerLayoutModeFromValue(json['layoutMode']),
      brightnessMode: readerBrightnessModeFromValue(json['brightnessMode']),
      brightness: (_asDouble(json['brightness']) ?? 1).clamp(0, 1),
      textAlign: readerTextAlignModeFromValue(json['textAlign']),
      pageTurnAnimation: readerPageTurnAnimationFromValue(
        json['pageTurnAnimation'],
      ),
      progressDisplay: readerProgressDisplayFromValue(json['progressDisplay']),
      enableDoublePageInLandscape:
          _asBool(json['enableDoublePageInLandscape']) ?? true,
      pageGap: _asDouble(json['pageGap']) ?? 24,
      gutterWidth: _asDouble(json['gutterWidth']) ?? 26,
      textIndentEnabled: _asBool(json['textIndentEnabled']) ?? false,
      textIndentEm: _asDouble(json['textIndentEm']) ?? 2,
      textIndentSkipFirstParagraph:
          _asBool(json['textIndentSkipFirstParagraph']) ?? true,
      customTextColor: _asString(json['customTextColor']),
      customBackgroundColor: _asString(json['customBackgroundColor']),
      customLinkColor: _asString(json['customLinkColor']),
      customSelectionColor: _asString(json['customSelectionColor']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toBridgeStyleJson({required bool doublePageEnabled}) {
    final isCustom = theme == ReaderTheme.custom;
    return <String, Object?>{
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily,
      'paddingTop': edgePadding,
      'paddingRight': edgePadding,
      'paddingBottom': edgePadding,
      'paddingLeft': edgePadding,
      'pageGap': pageGap,
      'columnCount': doublePageEnabled ? 2 : 1,
      'theme': theme.value,
      'textColor': isCustom ? customTextColor : null,
      'backgroundColor': isCustom ? customBackgroundColor : null,
      'linkColor': isCustom ? customLinkColor : null,
      'selectionColor': isCustom ? customSelectionColor : null,
      'gutterWidth': gutterWidth,
      'textIndentEnabled': textIndentEnabled,
      'textIndentEm': textIndentEm,
      'textIndentSkipFirstParagraph': textIndentSkipFirstParagraph,
    };
  }
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
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
