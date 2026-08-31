import 'package:foundation_domain/domain.dart';

/// 同步配置(服务器地址/token/设备ID/上次同步时间)。
class SyncConfig {
  const SyncConfig({
    required this.serverUrl,
    required this.token,
    required this.deviceId,
    this.lastSyncAt,
  });

  final String serverUrl;
  final String token;
  final String deviceId;

  /// 上次成功 pull 时服务器返回的时间(UTC)。null = 从未同步过。
  final DateTime? lastSyncAt;

  bool get isConfigured => serverUrl.trim().isNotEmpty && token.trim().isNotEmpty;

  SyncConfig copyWith({
    String? serverUrl,
    String? token,
    String? deviceId,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
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
