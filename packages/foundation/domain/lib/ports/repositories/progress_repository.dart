import '../../models/reading_progress.dart';

abstract class ProgressRepository {
  Future<ReadingProgress?> getProgress(String bookUid);

  Future<void> saveProgress(ReadingProgress progress);

  /// 枚举所有有进度记录的书(用于同步推送全量变更)。
  Future<List<ReadingProgress>> listProgress();
}
