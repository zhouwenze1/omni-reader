enum ImportTaskStatus { pending, success, failed, alreadyImported }

class ImportBookOptions {
  const ImportBookOptions({
    this.enableSmartTocReconciliation = true,
  });

  final bool enableSmartTocReconciliation;

  ImportBookOptions copyWith({
    bool? enableSmartTocReconciliation,
  }) {
    return ImportBookOptions(
      enableSmartTocReconciliation:
          enableSmartTocReconciliation ?? this.enableSmartTocReconciliation,
    );
  }
}

class ImportTask {
  const ImportTask({
    required this.id,
    required this.filePath,
    required this.status,
    this.bookUid,
    this.errorMessage,
    required this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String filePath;
  final ImportTaskStatus status;
  final String? bookUid;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? finishedAt;

  ImportTask copyWith({
    ImportTaskStatus? status,
    String? bookUid,
    String? errorMessage,
    DateTime? finishedAt,
  }) {
    return ImportTask(
      id: id,
      filePath: filePath,
      status: status ?? this.status,
      bookUid: bookUid ?? this.bookUid,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'status': status.name,
      'bookUid': bookUid,
      'errorMessage': errorMessage,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
    };
  }
}

class ImportResult {
  const ImportResult({
    required this.alreadyImported,
    this.bookUid,
    required this.task,
  });

  final bool alreadyImported;
  final String? bookUid;
  final ImportTask task;
}
