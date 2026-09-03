import 'package:foundation_domain/domain.dart';

/// 同步配置和本地同步状态。
class SyncConfig {
  const SyncConfig({
    required this.serverUrl,
    required this.token,
    required this.deviceId,
    this.lastSyncAt,
    this.cursor,
    this.syncedContentHashes = const <String, String>{},
  });

  final String serverUrl;
  final String token;
  final String deviceId;

  /// 上次成功 pull 时服务器返回的时间(UTC),仅用于界面展示。
  final DateTime? lastSyncAt;

  /// 服务端变更日志游标。null 表示尚未完成迁移。
  final int? cursor;

  /// 每本书最近一次已确认同步的内容指纹。
  final Map<String, String> syncedContentHashes;

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty && token.trim().isNotEmpty;

  SyncConfig copyWith({
    String? serverUrl,
    String? token,
    String? deviceId,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    int? cursor,
    bool clearCursor = false,
    Map<String, String>? syncedContentHashes,
    bool clearSyncedContentHashes = false,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      syncedContentHashes: clearSyncedContentHashes
          ? const <String, String>{}
          : (syncedContentHashes ?? this.syncedContentHashes),
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
