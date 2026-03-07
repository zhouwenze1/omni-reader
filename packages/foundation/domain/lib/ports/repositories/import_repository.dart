import '../../models/import_models.dart';

abstract class ImportRepository {
  Future<ImportResult> importBookFromFile(
    String filePath, {
    bool debugMode = false,
    ImportBookOptions options = const ImportBookOptions(),
  });
}
