import '../models/book_metadata.dart';
import '../models/parsed_book_package.dart';
import 'book_format.dart';

abstract interface class FormatParser<TPackage extends ParsedBookPackage> {
  BookFormat get format;

  bool supportsFile(String filePath);

  Future<TPackage> parseFromFile(String filePath);

  Future<BookMetadata> parseInfo(String filePath);
}
