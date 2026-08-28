import '../models/parsed_book_package.dart';
import 'book_format.dart';
import 'format_parser.dart';

class ParserRegistry {
  final Map<BookFormat, FormatParser<ParsedBookPackage>> _parsers =
      <BookFormat, FormatParser<ParsedBookPackage>>{};

  void register<TPackage extends ParsedBookPackage>(
    FormatParser<TPackage> parser,
  ) {
    _parsers[parser.format] = parser as FormatParser<ParsedBookPackage>;
  }

  bool supports(String filePath) {
    final format = BookFormat.fromFilePath(filePath);
    final parser = _parsers[format];
    return parser?.supportsFile(filePath) ?? false;
  }

  FormatParser<ParsedBookPackage>? parserForFile(String filePath) {
    final format = BookFormat.fromFilePath(filePath);
    return _parsers[format];
  }

  List<FormatParser<ParsedBookPackage>> get all =>
      _parsers.values.toList(growable: false);
}
