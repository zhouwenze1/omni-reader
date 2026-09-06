import '../../models/import_models.dart';

abstract class ImportRepository {
  Future<ImportResult> importBookFromFile(
    String filePath, {
    bool debugMode = false,
    ImportBookOptions options = const ImportBookOptions(),
  });

  /// 从云端取回的原始 EPUB 重建本地解析产物,保留已有进度/标注/书架元数据。
  ///
  /// [bookUid] 必须与文件指纹派生的 uid 一致;产物已完整时跳过解析。
  Future<ImportResult> restoreBookFromOriginalFile({
    required String bookUid,
    required String filePath,
  });
}
