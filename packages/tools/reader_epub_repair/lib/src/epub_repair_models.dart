enum EpubIssueSeverity { info, warning, error, fatal }

enum EpubRepairAction { unchanged, repaired, created, moved, skipped }

class EpubIssue {
  const EpubIssue({
    required this.code,
    required this.severity,
    required this.action,
    required this.message,
    this.path,
  });

  final String code;
  final EpubIssueSeverity severity;
  final EpubRepairAction action;
  final String message;
  final String? path;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'severity': severity.name,
    'action': action.name,
    'message': message,
    if (path != null) 'path': path,
  };
}

class EpubEntryChange {
  const EpubEntryChange({
    required this.path,
    required this.action,
    this.outputPath,
    this.reason,
  });

  final String path;
  final EpubRepairAction action;
  final String? outputPath;
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'action': action.name,
    if (outputPath != null) 'outputPath': outputPath,
    if (reason != null) 'reason': reason,
  };
}

class EpubInspection {
  const EpubInspection({
    required this.inputPath,
    required this.entryCount,
    required this.packagePath,
    required this.hasValidMimetype,
    required this.hasValidContainer,
    required this.hasValidPackage,
    required this.hasUsableNavigation,
    required this.issues,
  });

  final String inputPath;
  final int entryCount;
  final String? packagePath;
  final bool hasValidMimetype;
  final bool hasValidContainer;
  final bool hasValidPackage;
  final bool hasUsableNavigation;
  final List<EpubIssue> issues;

  bool get isValid =>
      issues.every((issue) => issue.severity != EpubIssueSeverity.fatal);

  Map<String, Object?> toJson() => <String, Object?>{
    'inputPath': inputPath,
    'entryCount': entryCount,
    'packagePath': packagePath,
    'hasValidMimetype': hasValidMimetype,
    'hasValidContainer': hasValidContainer,
    'hasValidPackage': hasValidPackage,
    'hasUsableNavigation': hasUsableNavigation,
    'issues': issues.map((issue) => issue.toJson()).toList(),
  };
}

class EpubRepairResult {
  const EpubRepairResult({
    required this.inputPath,
    required this.outputPath,
    required this.changed,
    required this.changes,
    required this.issues,
  });

  final String inputPath;
  final String outputPath;
  final bool changed;
  final List<EpubEntryChange> changes;
  final List<EpubIssue> issues;

  bool get hasFatalIssue =>
      issues.any((issue) => issue.severity == EpubIssueSeverity.fatal);

  Map<String, Object?> toJson() => <String, Object?>{
    'inputPath': inputPath,
    'outputPath': outputPath,
    'changed': changed,
    'changes': changes.map((change) => change.toJson()).toList(),
    'issues': issues.map((issue) => issue.toJson()).toList(),
  };
}

class EpubRepairException implements Exception {
  const EpubRepairException(this.message, {this.issues = const <EpubIssue>[]});

  final String message;
  final List<EpubIssue> issues;

  @override
  String toString() => 'EpubRepairException: $message';
}
