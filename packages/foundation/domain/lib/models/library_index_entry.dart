/// 云端备份状态。
enum CloudBackupStatus {
  /// 未入云(从未上传或已确认云端删除)。
  none,

  /// 待上传(排队中或上次上传失败,下个触发点重试)。
  pending,

  /// 云端已有完整副本。
  synced;

  static CloudBackupStatus fromString(String? value) {
    return CloudBackupStatus.values.firstWhere(
      (it) => it.name == value,
      orElse: () => CloudBackupStatus.none,
    );
  }

  String get storageName => name;
}

class LibraryIndexEntry {
  const LibraryIndexEntry({
    required this.bookUid,
    required this.fingerprint,
    required this.format,
    required this.title,
    required this.authors,
    this.categoryId,
    this.coverRelPath,
    required this.importedAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.cachedProgress,
    this.cloudStatus = CloudBackupStatus.none,
    this.evictedAt,
    this.pinLocal = false,
  });

  final String bookUid;
  final String fingerprint;
  final String format;
  final String title;
  final List<String> authors;
  final String? categoryId;
  final String? coverRelPath;
  final DateTime importedAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final double? cachedProgress;

  /// 云端备份状态。
  final CloudBackupStatus cloudStatus;

  /// 非空表示本地大文件(解析产物+原始文件)已释放,仅保留封面/进度/标注。
  final DateTime? evictedAt;

  /// 固定在本地:自动清理永不释放该书。
  final bool pinLocal;

  /// 书架条目对应的本地数据是否完整可打开。
  bool get isAvailableLocally => evictedAt == null;

  LibraryIndexEntry copyWith({
    String? format,
    String? title,
    String? categoryId,
    String? coverRelPath,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    bool clearLastOpenedAt = false,
    double? cachedProgress,
    bool clearCachedProgress = false,
    CloudBackupStatus? cloudStatus,
    DateTime? evictedAt,
    bool clearEvictedAt = false,
    bool? pinLocal,
  }) {
    return LibraryIndexEntry(
      bookUid: bookUid,
      fingerprint: fingerprint,
      format: format ?? this.format,
      title: title ?? this.title,
      authors: authors,
      categoryId: categoryId ?? this.categoryId,
      coverRelPath: coverRelPath ?? this.coverRelPath,
      importedAt: importedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: clearLastOpenedAt
          ? null
          : (lastOpenedAt ?? this.lastOpenedAt),
      cachedProgress:
          clearCachedProgress ? null : (cachedProgress ?? this.cachedProgress),
      cloudStatus: cloudStatus ?? this.cloudStatus,
      evictedAt: clearEvictedAt ? null : (evictedAt ?? this.evictedAt),
      pinLocal: pinLocal ?? this.pinLocal,
    );
  }

  factory LibraryIndexEntry.fromJson(Map<String, dynamic> json) {
    return LibraryIndexEntry(
      bookUid: json['bookUid'] as String,
      fingerprint: json['fingerprint'] as String,
      format: json['format'] as String,
      title: json['title'] as String,
      authors: (json['authors'] as List<dynamic>? ?? const [])
          .map((it) => '$it')
          .toList(),
      categoryId: json['categoryId'] as String?,
      coverRelPath: json['coverRelPath'] as String?,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['importedAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num).toInt(),
      ),
      lastOpenedAt: json['lastOpenedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['lastOpenedAt'] as num).toInt(),
            ),
      cachedProgress: (json['cachedProgress'] as num?)?.toDouble(),
      cloudStatus: CloudBackupStatus.fromString(json['cloudStatus'] as String?),
      evictedAt: json['evictedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['evictedAt'] as num).toInt(),
            ),
      pinLocal: (json['pinLocal'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookUid': bookUid,
      'fingerprint': fingerprint,
      'format': format,
      'title': title,
      'authors': authors,
      'categoryId': categoryId,
      'coverRelPath': coverRelPath,
      'importedAt': importedAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lastOpenedAt': lastOpenedAt?.millisecondsSinceEpoch,
      'cachedProgress': cachedProgress,
      'cloudStatus': cloudStatus.storageName,
      'evictedAt': evictedAt?.millisecondsSinceEpoch,
      'pinLocal': pinLocal,
    };
  }
}
