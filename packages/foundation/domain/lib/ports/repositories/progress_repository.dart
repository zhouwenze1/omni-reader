import '../../models/reading_progress.dart';

abstract class ProgressRepository {
  Future<ReadingProgress?> getProgress(String bookUid);

  Future<void> saveProgress(ReadingProgress progress);

  /// 枚举所有有进度记录的书,供同步服务计算本地内容变化。
  Future<List<ReadingProgress>> listProgress();
}
