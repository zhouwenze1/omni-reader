enum ImportTaskStatus { queued, running, succeeded, failed, canceled }

extension ImportTaskStatusX on ImportTaskStatus {
  String get value {
    switch (this) {
      case ImportTaskStatus.queued:
        return 'queued';
      case ImportTaskStatus.running:
        return 'running';
      case ImportTaskStatus.succeeded:
        return 'succeeded';
      case ImportTaskStatus.failed:
        return 'failed';
      case ImportTaskStatus.canceled:
        return 'canceled';
    }
  }
}

ImportTaskStatus importTaskStatusFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'running':
      return ImportTaskStatus.running;
    case 'succeeded':
      return ImportTaskStatus.succeeded;
    case 'failed':
      return ImportTaskStatus.failed;
    case 'canceled':
      return ImportTaskStatus.canceled;
    default:
      return ImportTaskStatus.queued;
  }
}

enum ImportSourceType { filePicker, folderScan, cloudSync, shareIntent, manual }

extension ImportSourceTypeX on ImportSourceType {
  String get value {
    switch (this) {
      case ImportSourceType.filePicker:
        return 'file_picker';
      case ImportSourceType.folderScan:
        return 'folder_scan';
      case ImportSourceType.cloudSync:
        return 'cloud_sync';
      case ImportSourceType.shareIntent:
        return 'share_intent';
      case ImportSourceType.manual:
        return 'manual';
    }
  }
}

ImportSourceType importSourceTypeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'folder_scan':
      return ImportSourceType.folderScan;
    case 'cloud_sync':
      return ImportSourceType.cloudSync;
    case 'share_intent':
      return ImportSourceType.shareIntent;
    case 'manual':
      return ImportSourceType.manual;
    default:
      return ImportSourceType.filePicker;
  }
}

class ImportTask {
  const ImportTask({
    required this.id,
    required this.sourceType,
    required this.createdAt,
    this.status = ImportTaskStatus.queued,
    this.progress = 0,
    this.sourcePath,
    this.errorMessage,
    this.discoveredPaths = const <String>[],
    this.importedBookIds = const <String>[],
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final ImportSourceType sourceType;
  final ImportTaskStatus status;
  final double progress;
  final String? sourcePath;
  final String? errorMessage;
  final List<String> discoveredPaths;
  final List<String> importedBookIds;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isDone {
    return status == ImportTaskStatus.succeeded ||
        status == ImportTaskStatus.failed ||
        status == ImportTaskStatus.canceled;
  }

  ImportTask copyWith({
    String? id,
    ImportSourceType? sourceType,
    ImportTaskStatus? status,
    double? progress,
    String? sourcePath,
    String? errorMessage,
    List<String>? discoveredPaths,
    List<String>? importedBookIds,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return ImportTask(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sourcePath: sourcePath ?? this.sourcePath,
      errorMessage: errorMessage ?? this.errorMessage,
      discoveredPaths: discoveredPaths ?? this.discoveredPaths,
      importedBookIds: importedBookIds ?? this.importedBookIds,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sourceType': sourceType.value,
      'status': status.value,
      'progress': progress,
      'sourcePath': sourcePath,
      'errorMessage': errorMessage,
      'discoveredPaths': discoveredPaths,
      'importedBookIds': importedBookIds,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  factory ImportTask.fromJson(Map<String, Object?> json) {
    return ImportTask(
      id: _asString(json['id']) ?? '',
      sourceType: importSourceTypeFromValue(json['sourceType']),
      status: importTaskStatusFromValue(json['status']),
      progress: _asDouble(json['progress']) ?? 0,
      sourcePath: _asString(json['sourcePath']),
      errorMessage: _asString(json['errorMessage']),
      discoveredPaths: _asStringList(json['discoveredPaths']),
      importedBookIds: _asStringList(json['importedBookIds']),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      startedAt: _asDateTime(json['startedAt']),
      finishedAt: _asDateTime(json['finishedAt']),
    );
  }
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is List<String>) {
    return value;
  }
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const <String>[];
}
