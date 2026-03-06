class ReaderStyle {
  const ReaderStyle({
    this.theme = 'day',
    this.columnCount = 1,
    this.pageGap = 24,
    this.fontSize = 20,
    this.lineHeight = 1.6,
    this.paddingTop = 16,
    this.paddingRight = 36,
    this.paddingBottom = 16,
    this.paddingLeft = 36,
    this.textIndentEnabled = true,
    this.textIndentEm = 2.0,
    this.textIndentSkipFirstParagraph = false,
  });

  static const ReaderStyle defaults = ReaderStyle();

  final String theme;
  final int columnCount;
  final int pageGap;
  final int fontSize;
  final double lineHeight;
  final int paddingTop;
  final int paddingRight;
  final int paddingBottom;
  final int paddingLeft;
  final bool textIndentEnabled;
  final double textIndentEm;
  final bool textIndentSkipFirstParagraph;

  factory ReaderStyle.fromJson(Map<String, dynamic> json) {
    return ReaderStyle(
      theme: (json['theme'] as String?) ?? defaults.theme,
      columnCount:
          (json['columnCount'] as num?)?.toInt() ?? defaults.columnCount,
      pageGap: (json['pageGap'] as num?)?.toInt() ?? defaults.pageGap,
      fontSize: (json['fontSize'] as num?)?.toInt() ?? defaults.fontSize,
      lineHeight:
          (json['lineHeight'] as num?)?.toDouble() ?? defaults.lineHeight,
      paddingTop: (json['paddingTop'] as num?)?.toInt() ?? defaults.paddingTop,
      paddingRight:
          (json['paddingRight'] as num?)?.toInt() ?? defaults.paddingRight,
      paddingBottom:
          (json['paddingBottom'] as num?)?.toInt() ?? defaults.paddingBottom,
      paddingLeft:
          (json['paddingLeft'] as num?)?.toInt() ?? defaults.paddingLeft,
      textIndentEnabled:
          (json['textIndentEnabled'] as bool?) ?? defaults.textIndentEnabled,
      textIndentEm:
          (json['textIndentEm'] as num?)?.toDouble() ?? defaults.textIndentEm,
      textIndentSkipFirstParagraph:
          (json['textIndentSkipFirstParagraph'] as bool?) ??
              defaults.textIndentSkipFirstParagraph,
    );
  }

  ReaderStyle copyWith({
    String? theme,
    int? columnCount,
    int? pageGap,
    int? fontSize,
    double? lineHeight,
    int? paddingTop,
    int? paddingRight,
    int? paddingBottom,
    int? paddingLeft,
    bool? textIndentEnabled,
    double? textIndentEm,
    bool? textIndentSkipFirstParagraph,
  }) {
    return ReaderStyle(
      theme: theme ?? this.theme,
      columnCount: columnCount ?? this.columnCount,
      pageGap: pageGap ?? this.pageGap,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingRight: paddingRight ?? this.paddingRight,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      textIndentEnabled: textIndentEnabled ?? this.textIndentEnabled,
      textIndentEm: textIndentEm ?? this.textIndentEm,
      textIndentSkipFirstParagraph:
          textIndentSkipFirstParagraph ?? this.textIndentSkipFirstParagraph,
    );
  }

  ReaderStyle mergePatch(Map<String, dynamic> patch) {
    return copyWith(
      theme: patch['theme'] as String?,
      columnCount: (patch['columnCount'] as num?)?.toInt(),
      pageGap: (patch['pageGap'] as num?)?.toInt(),
      fontSize: (patch['fontSize'] as num?)?.toInt(),
      lineHeight: (patch['lineHeight'] as num?)?.toDouble(),
      paddingTop: (patch['paddingTop'] as num?)?.toInt(),
      paddingRight: (patch['paddingRight'] as num?)?.toInt(),
      paddingBottom: (patch['paddingBottom'] as num?)?.toInt(),
      paddingLeft: (patch['paddingLeft'] as num?)?.toInt(),
      textIndentEnabled: patch['textIndentEnabled'] as bool?,
      textIndentEm: (patch['textIndentEm'] as num?)?.toDouble(),
      textIndentSkipFirstParagraph:
          patch['textIndentSkipFirstParagraph'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'theme': theme,
      'columnCount': columnCount,
      'pageGap': pageGap,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'paddingTop': paddingTop,
      'paddingRight': paddingRight,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'textIndentEnabled': textIndentEnabled,
      'textIndentEm': textIndentEm,
      'textIndentSkipFirstParagraph': textIndentSkipFirstParagraph,
    };
  }
}
