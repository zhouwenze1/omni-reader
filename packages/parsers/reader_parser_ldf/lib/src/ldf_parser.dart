import 'package:reader_parser_core/reader_parser_core.dart';

class LdfParser implements FormatParser<ParsedBookPackage> {
  @override
  BookFormat get format => BookFormat.ldf;

  @override
  bool supportsFile(String filePath) {
    return BookFormat.fromFilePath(filePath) == BookFormat.ldf;
  }

  @override
  Future<ParsedBookPackage> parseFromFile(String filePath) {
    throw UnimplementedError('LDF parser is not implemented yet.');
  }

  @override
  Future<BookMetadata> parseInfo(String filePath) {
    throw UnimplementedError('LDF parser is not implemented yet.');
  }
}
