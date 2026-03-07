import 'package:foundation_domain/domain.dart';

class ImportBookUseCase {
  const ImportBookUseCase(this._importRepository);

  final ImportRepository _importRepository;

  Future<ImportResult> call(
    String filePath, {
    bool debugMode = false,
    ImportBookOptions options = const ImportBookOptions(),
  }) {
    return _importRepository.importBookFromFile(
      filePath,
      debugMode: debugMode,
      options: options,
    );
  }
}

class ListLibraryIndexUseCase {
  const ListLibraryIndexUseCase(this._bookRepository);

  final BookRepository _bookRepository;

  Future<List<LibraryIndexEntry>> call() {
    return _bookRepository.listLibraryIndex();
  }
}
