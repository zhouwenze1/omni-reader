import 'dart:async';

import 'package:foundation_domain/domain.dart';

import 'sync_api_client.dart';
import 'sync_ports.dart';

/// 同步操作结果。
class SyncResult {
  const SyncResult({this.pushed = 0, this.pulled = 0});

  final int pushed;
  final int pulled;

  bool get hasChanges => pushed > 0 || pulled > 0;
}

/// 阅读进度同步服务。负责协调本地进度 ↔ 远程服务器的双向同步。
class ProgressSyncService {
  ProgressSyncService({
    required SyncApiClient api,
    required ProgressSyncSource source,
    required SyncConfigStore configStore,
  })  : _api = api,
        _source = source,
        _configStore = configStore;

  final SyncApiClient _api;
  final ProgressSyncSource _source;
  final SyncConfigStore _configStore;

  /// 单次同步操作的超时:打开图书/退出阅读不能因服务器慢而卡住。
  static const Duration _timeout = Duration(seconds: 8);

  /// 读取当前配置。
  SyncConfig getConfig() => _configStore.load();

  /// 保存配置(服务器地址/token 等)。
  Future<void> saveConfig(SyncConfig config) => _configStore.save(config);

  /// 打开图书前:拉取该书远端进度,若远端 updatedAt 更新则写入本地,并返回
  /// 远端进度(供调用方接管初始位置)。超时/失败时返回 null,不阻塞阅读。
  Future<ReadingProgress?> pullBookOnOpen(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return null;

    try {
      final result = await _api
          .pull(
            serverUrl: config.serverUrl,
            token: config.token,
            deviceId: config.deviceId,
            bookUid: bookUid,
          )
          .timeout(_timeout);
      if (result.items.isEmpty) return null;

      final remote = result.items.first;
      final local = await _source.getProgress(bookUid);

      // 远端更新,则写入本地后返回。
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _source.saveProgress(remote);
        return remote;
      }
      return null;
    } catch (_) {
      return null; // 静默失败,不阻塞打开图书
    }
  }

  /// 阅读页退出后:推送该书的本地进度到服务器。
  Future<SyncResult> pushBookOnExit(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return const SyncResult();

    try {
      final local = await _source.getProgress(bookUid);
      if (local == null) return const SyncResult();

      final accepted = await _api
          .push(
            serverUrl: config.serverUrl,
            token: config.token,
            deviceId: config.deviceId,
            items: [local],
          )
          .timeout(_timeout);
      return SyncResult(pushed: accepted);
    } catch (_) {
      return const SyncResult(); // 静默失败,下次再试
    }
  }

  /// 应用启动/手动同步:推送所有本地变更,拉取所有远端增量,按 updatedAt 合并。
  Future<SyncResult> syncAll() async {
    final config = _configStore.load();
    if (!config.isConfigured) return const SyncResult();

    var pushed = 0;
    var pulled = 0;

    try {
      // 1. 推送本地所有有进度的书
      final all = await _source.listAllProgress();
      if (all.isNotEmpty) {
        final accepted = await _api
            .push(
              serverUrl: config.serverUrl,
              token: config.token,
              deviceId: config.deviceId,
              items: all,
            )
            .timeout(_timeout);
        pushed = accepted;
      }

      // 2. 拉取远端增量
      final result = await _api
          .pull(
            serverUrl: config.serverUrl,
            token: config.token,
            deviceId: config.deviceId,
            after: config.lastSyncAt,
          )
          .timeout(_timeout);

      // 3. 逐条合并(远端更新才写本地)
      for (final remote in result.items) {
        if (!await _source.hasBook(remote.bookUid)) {
          continue; // 本地没这本书,静默跳过
        }
        final local = await _source.getProgress(remote.bookUid);
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          await _source.saveProgress(remote);
          pulled++;
        }
      }

      // 4. 推进游标
      if (result.serverTime.isAfter(config.lastSyncAt ?? DateTime.utc(1970))) {
        await _configStore.save(config.copyWith(lastSyncAt: result.serverTime));
      }

      return SyncResult(pushed: pushed, pulled: pulled);
    } catch (_) {
      // 静默失败,下次再试
      return SyncResult(pushed: pushed, pulled: pulled);
    }
  }
}