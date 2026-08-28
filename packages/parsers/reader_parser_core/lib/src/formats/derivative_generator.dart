import '../models/parsed_book_package.dart';

abstract interface class DerivativeGenerator<
    TPackage extends ParsedBookPackage> {
  Future<TPackage> generateArtifacts(TPackage package);
}

