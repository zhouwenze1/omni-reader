import 'package:foundation_domain/domain.dart';

/// 同步配置和本地同步状态。
class SyncConfig {
  const SyncConfig({
    required this.serverUrl,
    required this.token,
    required this.deviceId,
    this.autoSync = true,
    this.wifiOnly = true,
    this.autoEvictEnabled = false,
    this.autoEvictDays = 30,
    this.lastSyncAt,
    this.cursor,
    this.manifestSyncedAt,
    this.syncedContentHashes = const <String, String>{},
    this.syncAnnotations = true,
    this.syncSettings = true,
    this.syncStats = true,
    this.entityCursors = const <String, int>{},
    this.styleSyncedHash,
    this.styleSyncedAt,
    this.statsPushedUntil,
    this.webdavEnabled = false,
    this.webdavUrl = '',
    this.webdavUsername = '',
    this.webdavPassword = '',
  });

  final String serverUrl;
  final String token;
  final String deviceId;

  /// 自动同步总开关。未配置服务器时视为关闭(见 [autoSyncActive])。
  final bool autoSync;

  /// 移动端仅 Wi-Fi 上下传(桌面端忽略)。
  final bool wifiOnly;

  /// 自动释放 N 天未读书的本地大文件(书库云备份)。
  final bool autoEvictEnabled;
  final int autoEvictDays;

  /// 上次成功 pull 时服务器返回的时间(UTC),仅用于界面展示。
  final DateTime? lastSyncAt;

  /// 服务端变更日志游标。null 表示尚未完成迁移。
  final int? cursor;

  /// 书单增量同步位点(服务端 updated_at 毫秒)。
  final int? manifestSyncedAt;

  /// 每本书最近一次已确认同步的内容指纹。
  final Map<String, String> syncedContentHashes;

  /// 同步内容开关:标注/阅读设置/阅读统计(进度恒开)。
  final bool syncAnnotations;
  final bool syncSettings;
  final bool syncStats;

  /// v2 实体(标注/设置/统计)的增量拉取游标,键为实体名。
  final Map<String, int> entityCursors;

  /// 阅读设置最近一次确认同步的内容指纹(LWW 基线)。
  final String? styleSyncedHash;

  /// 阅读设置最近一次确认同步的时间(毫秒),远端更新时用于比较新旧。
  final int? styleSyncedAt;

  /// 统计会话已推送位点(本地 startedAt 毫秒)。
  final int? statsPushedUntil;

  /// WebDAV 文件后端:启用后书文件上传/取回改走用户自有 WebDAV,
  /// 书单/封面/进度/标注仍走自建服务器。
  final bool webdavEnabled;
  final String webdavUrl;
  final String webdavUsername;
  final String webdavPassword;

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty && token.trim().isNotEmpty;

  bool get webdavConfigured =>
      webdavEnabled &&
      webdavUrl.trim().isNotEmpty;

  /// 自动触发(开书拉取/合书推送/启动同步/书库备份)是否生效;手动同步不受限。
  bool get autoSyncActive => isConfigured && autoSync;

  SyncConfig copyWith({
    String? serverUrl,
    String? token,
    String? deviceId,
    bool? autoSync,
    bool? wifiOnly,
    bool? autoEvictEnabled,
    int? autoEvictDays,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    int? cursor,
    bool clearCursor = false,
    int? manifestSyncedAt,
    bool clearManifestSyncedAt = false,
    Map<String, String>? syncedContentHashes,
    bool clearSyncedContentHashes = false,
    bool? syncAnnotations,
    bool? syncSettings,
    bool? syncStats,
    Map<String, int>? entityCursors,
    bool clearEntityCursors = false,
    String? styleSyncedHash,
    bool clearStyleSyncedHash = false,
    int? styleSyncedAt,
    bool clearStyleSyncedAt = false,
    int? statsPushedUntil,
    bool clearStatsPushedUntil = false,
    bool? webdavEnabled,
    String? webdavUrl,
    String? webdavUsername,
    String? webdavPassword,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      autoSync: autoSync ?? this.autoSync,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoEvictEnabled: autoEvictEnabled ?? this.autoEvictEnabled,
      autoEvictDays: autoEvictDays ?? this.autoEvictDays,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      manifestSyncedAt: clearManifestSyncedAt
          ? null
          : (manifestSyncedAt ?? this.manifestSyncedAt),
      syncedContentHashes: clearSyncedContentHashes
          ? const <String, String>{}
          : (syncedContentHashes ?? this.syncedContentHashes),
      syncAnnotations: syncAnnotations ?? this.syncAnnotations,
      syncSettings: syncSettings ?? this.syncSettings,
      syncStats: syncStats ?? this.syncStats,
      entityCursors: clearEntityCursors
          ? const <String, int>{}
          : (entityCursors ?? this.entityCursors),
      styleSyncedHash:
          clearStyleSyncedHash ? null : (styleSyncedHash ?? this.styleSyncedHash),
      styleSyncedAt:
          clearStyleSyncedAt ? null : (styleSyncedAt ?? this.styleSyncedAt),
      statsPushedUntil:
          clearStatsPushedUntil ? null : (statsPushedUntil ?? this.statsPushedUntil),
      webdavEnabled: webdavEnabled ?? this.webdavEnabled,
      webdavUrl: webdavUrl ?? this.webdavUrl,
      webdavUsername: webdavUsername ?? this.webdavUsername,
      webdavPassword: webdavPassword ?? this.webdavPassword,
    );
  }
}

/// 同步配置持久化端口,由宿主(App)用 Hive/SharedPreferences 实现。
abstract class SyncConfigStore {
  SyncConfig load();

  Future<void> save(SyncConfig config);
}

/// 进度数据端口,由宿主用现有 ProgressRepository 实现。
abstract class ProgressSyncSource {
  Future<ReadingProgress?> getProgress(String bookUid);

  /// 枚举本机所有有进度的书。
  Future<List<ReadingProgress>> listAllProgress();

  Future<void> saveProgress(ReadingProgress progress);

  /// 书是否在本机书架中(不在则静默跳过,等导入后接上)。
  Future<bool> hasBook(String bookUid);
}

/// 标注删除墓碑:本机已删、待传播到其他设备。
class AnnotationTombstone {
  const AnnotationTombstone({
    required this.id,
    required this.bookUid,
    required this.updatedAt,
  });

  final String id;
  final String bookUid;

  /// 删除发生时间(毫秒),对端按 LWW 与标注修改时间比较。
  final int updatedAt;
}

/// 标注同步端口:由宿主用 AnnotationRepository 实现。
abstract class AnnotationSyncSource {
  /// 书的全部标注(推送与合并都以书为单位整体读写)。
  Future<List<Annotation>> listAnnotations(String bookUid);

  Future<void> replaceAnnotations(
    String bookUid,
    List<Annotation> annotations,
  );

  /// 待传播的删除墓碑(只读快照,推送成功后用 [confirmTombstones] 确认)。
  Future<List<AnnotationTombstone>> pendingAnnotationTombstones();

  Future<void> confirmTombstones(List<String> ids);
}

/// 阅读设置同步端口:由宿主用 SettingsRepository 实现。
abstract class SettingsSyncSource {
  Future<ReaderSettings> getReaderSettings();

  Future<void> saveReaderSettings(ReaderSettings settings);
}

/// 阅读统计同步端口:由宿主用 ReadingStatsRepository 实现。
abstract class StatsSyncSource {
  /// 本机 [sinceMs] 之后开始的会话(推送游标用)。
  Future<List<ReadingSessionRecord>> sessionsSince(int sinceMs);

  /// (deviceId, startedAt) 会话是否已存在(拉取去重)。
  Future<bool> hasSession({
    required String deviceId,
    required int startedAtMs,
  });

  Future<void> insertSyncedSession(ReadingSessionRecord record);
}
