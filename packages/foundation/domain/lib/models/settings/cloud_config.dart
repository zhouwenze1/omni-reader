enum CloudProviderType { googleDrive, oneDrive }

extension CloudProviderTypeX on CloudProviderType {
  String get value {
    switch (this) {
      case CloudProviderType.googleDrive:
        return 'google_drive';
      case CloudProviderType.oneDrive:
        return 'one_drive';
    }
  }
}

CloudProviderType cloudProviderTypeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'one_drive':
      return CloudProviderType.oneDrive;
    default:
      return CloudProviderType.googleDrive;
  }
}

enum CloudProviderStatus { disconnected, connecting, connected, error }

extension CloudProviderStatusX on CloudProviderStatus {
  String get value {
    switch (this) {
      case CloudProviderStatus.disconnected:
        return 'disconnected';
      case CloudProviderStatus.connecting:
        return 'connecting';
      case CloudProviderStatus.connected:
        return 'connected';
      case CloudProviderStatus.error:
        return 'error';
    }
  }
}

CloudProviderStatus cloudProviderStatusFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'connecting':
      return CloudProviderStatus.connecting;
    case 'connected':
      return CloudProviderStatus.connected;
    case 'error':
      return CloudProviderStatus.error;
    default:
      return CloudProviderStatus.disconnected;
  }
}

class CloudProviderConfig {
  const CloudProviderConfig({
    required this.type,
    this.status = CloudProviderStatus.disconnected,
    this.accountId,
    this.accountName,
    this.connectedAt,
    this.lastSyncAt,
    this.errorMessage,
  });

  final CloudProviderType type;
  final CloudProviderStatus status;
  final String? accountId;
  final String? accountName;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;
  final String? errorMessage;

  bool get isConnected => status == CloudProviderStatus.connected;

  CloudProviderConfig copyWith({
    CloudProviderType? type,
    CloudProviderStatus? status,
    String? accountId,
    String? accountName,
    DateTime? connectedAt,
    DateTime? lastSyncAt,
    String? errorMessage,
  }) {
    return CloudProviderConfig(
      type: type ?? this.type,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type.value,
      'status': status.value,
      'accountId': accountId,
      'accountName': accountName,
      'connectedAt': connectedAt?.toIso8601String(),
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory CloudProviderConfig.fromJson(Map<String, Object?> json) {
    return CloudProviderConfig(
      type: cloudProviderTypeFromValue(json['type']),
      status: cloudProviderStatusFromValue(json['status']),
      accountId: _asString(json['accountId']),
      accountName: _asString(json['accountName']),
      connectedAt: _asDateTime(json['connectedAt']),
      lastSyncAt: _asDateTime(json['lastSyncAt']),
      errorMessage: _asString(json['errorMessage']),
    );
  }
}

class CloudSyncOptions {
  const CloudSyncOptions({
    this.storeOriginalFiles = true,
    this.storeReadingProgress = true,
    this.storeNotes = true,
    this.storeHighlights = true,
    this.storeAppData = true,
  });

  final bool storeOriginalFiles;
  final bool storeReadingProgress;
  final bool storeNotes;
  final bool storeHighlights;
  final bool storeAppData;

  CloudSyncOptions copyWith({
    bool? storeOriginalFiles,
    bool? storeReadingProgress,
    bool? storeNotes,
    bool? storeHighlights,
    bool? storeAppData,
  }) {
    return CloudSyncOptions(
      storeOriginalFiles: storeOriginalFiles ?? this.storeOriginalFiles,
      storeReadingProgress: storeReadingProgress ?? this.storeReadingProgress,
      storeNotes: storeNotes ?? this.storeNotes,
      storeHighlights: storeHighlights ?? this.storeHighlights,
      storeAppData: storeAppData ?? this.storeAppData,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'storeOriginalFiles': storeOriginalFiles,
      'storeReadingProgress': storeReadingProgress,
      'storeNotes': storeNotes,
      'storeHighlights': storeHighlights,
      'storeAppData': storeAppData,
    };
  }

  factory CloudSyncOptions.fromJson(Map<String, Object?> json) {
    return CloudSyncOptions(
      storeOriginalFiles: _asBool(json['storeOriginalFiles']) ?? true,
      storeReadingProgress: _asBool(json['storeReadingProgress']) ?? true,
      storeNotes: _asBool(json['storeNotes']) ?? true,
      storeHighlights: _asBool(json['storeHighlights']) ?? true,
      storeAppData: _asBool(json['storeAppData']) ?? true,
    );
  }
}

class CloudConfig {
  const CloudConfig({
    this.providers = const <CloudProviderType, CloudProviderConfig>{},
    this.options = const CloudSyncOptions(),
    this.updatedAt,
  });

  final Map<CloudProviderType, CloudProviderConfig> providers;
  final CloudSyncOptions options;
  final DateTime? updatedAt;

  CloudProviderConfig provider(CloudProviderType type) {
    return providers[type] ?? CloudProviderConfig(type: type);
  }

  CloudConfig copyWith({
    Map<CloudProviderType, CloudProviderConfig>? providers,
    CloudSyncOptions? options,
    DateTime? updatedAt,
  }) {
    return CloudConfig(
      providers: providers ?? this.providers,
      options: options ?? this.options,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'providers': providers.map(
        (key, value) => MapEntry(key.value, value.toJson()),
      ),
      'options': options.toJson(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory CloudConfig.fromJson(Map<String, Object?> json) {
    final providerMap = <CloudProviderType, CloudProviderConfig>{};
    final rawProviders = _asMap(json['providers']) ?? const <String, Object?>{};
    for (final entry in rawProviders.entries) {
      final type = cloudProviderTypeFromValue(entry.key);
      final configMap = _asMap(entry.value) ?? const <String, Object?>{};
      providerMap[type] = CloudProviderConfig.fromJson(configMap);
    }
    return CloudConfig(
      providers: providerMap,
      options: _asMap(json['options']) == null
          ? const CloudSyncOptions()
          : CloudSyncOptions.fromJson(_asMap(json['options'])!),
      updatedAt: _asDateTime(json['updatedAt']),
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

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return null;
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

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
