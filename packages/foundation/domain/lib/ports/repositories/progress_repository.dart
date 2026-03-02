import '../../models/reading_progress.dart';

abstract class ProgressRepository {
  Future<ReadingProgress?> getProgress(String bookUid);

  Future<void> saveProgress(ReadingProgress progress);
}
