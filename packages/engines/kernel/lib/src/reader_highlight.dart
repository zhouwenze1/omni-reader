class ReaderTextQuote {
  const ReaderTextQuote({
    required this.prefix,
    required this.exact,
    required this.suffix,
  });

  final String prefix;
  final String exact;
  final String suffix;

  bool get isUsable => exact.trim().isNotEmpty;

  factory ReaderTextQuote.fromJson(dynamic value) {
    final map = _asMap(value);
    if (map == null) {
      return const ReaderTextQuote(prefix: '', exact: '', suffix: '');
    }
    return ReaderTextQuote(
      prefix: _asString(map['prefix']),
      exact: _asString(map['exact']),
      suffix: _asString(map['suffix']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prefix': prefix,
        'exact': exact,
        'suffix': suffix,
      };

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  static String _asString(dynamic value) => value is String ? value : '';
}

class ReaderHighlight {
  const ReaderHighlight({
    required this.uid,
    required this.href,
    required this.color,
    required this.quote,
    this.cfi,
  });

  final String uid;
  final String href;
  final String color;
  final ReaderTextQuote quote;
  final String? cfi;
}

class ReaderSelectionQuote {
  const ReaderSelectionQuote({
    required this.href,
    required this.quote,
    this.cfi,
  });

  final String href;
  final ReaderTextQuote quote;
  final String? cfi;
}
