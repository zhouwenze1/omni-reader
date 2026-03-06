import 'package:foundation_domain/domain.dart';

class ImportState {
  const ImportState({
    required this.isImporting,
    required this.tasks,
    this.errorMessage,
  });

  const ImportState.initial()
      : isImporting = false,
        tasks = const <ImportTask>[],
        errorMessage = null;

  final bool isImporting;
  final List<ImportTask> tasks;
  final String? errorMessage;

  int get successCount =>
      tasks.where((task) => task.status == ImportTaskStatus.success).length;

  int get failedCount =>
      tasks.where((task) => task.status == ImportTaskStatus.failed).length;

  int get alreadyImportedCount => tasks
      .where((task) => task.status == ImportTaskStatus.alreadyImported)
      .length;

  ImportState copyWith({
    bool? isImporting,
    List<ImportTask>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImportState(
      isImporting: isImporting ?? this.isImporting,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
