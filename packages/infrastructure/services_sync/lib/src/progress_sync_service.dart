import 'dart:async';

import 'package:foundation_domain/domain.dart';

import 'content_hasher.dart';
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

  /// 同步不能阻塞阅读,网络请求只在后台等待有限时间。
  static const Duration _timeout = Duration(seconds: 8);

  /// 读取当前配置。
  SyncConfig getConfig() => _configStore.load();

  /// 保存配置。服务器身份变化后必须重新建立同步基线。
  Future<void> saveConfig(SyncConfig config) async {
    final current = _configStore.load();
    final identityChanged =
        current.serverUrl.trim() != config.serverUrl.trim() ||
            current.token != config.token ||
            current.deviceId != config.deviceId;
    final next = identityChanged
        ? config.copyWith(
            clearLastSyncAt: true,
            clearCursor: true,
            clearSyncedContentHashes: true,
          )
        : config;
    await _configStore.save(next);
  }

  /// 打开图书前拉取该书的最新进度。
  ///
  /// 已建立游标后,本地有未同步内容时先推送,再读取服务器当前值;
  /// 首次迁移则让服务器已有值作为基线,避免覆盖旧服务器数据。
  Future<ReadingProgress?> pullBookOnOpen(String bookUid) {
    return _pullBookOnOpen(bookUid);
  }

  /// 阅读页退出后,只推送内容指纹发生变化的书籍。
  Future<SyncResult> pushBookOnExit(String bookUid) {
    return _pushBookOnExit(bookUid);
  }

  /// 应用启动/手动同步:增量推送本地变化,再按服务端游标拉取变化。
  Future<SyncResult> syncAll() {
    return _syncAllInternal();
  }

  Future<ReadingProgress?> _pullBookOnOpen(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return null;

    try {
      var state = config;

      // 迁移完成后,本地尚未确认的内容先到达服务器,遵循服务器到达顺序。
      if (state.cursor != null) {
        final local = await _source.getProgress(bookUid);
        if (local != null) {
          final localHash = readingProgressContentHash(local);
          if (state.syncedContentHashes[bookUid] != localHash) {
            final pushed = await _push(state, [local]);
            if (pushed.accepted > 0) {
              await _saveHashes(<String, String>{bookUid: localHash});
            }
          }
        }
      }

      final result = await _api
          .pull(
            serverUrl: state.serverUrl,
            token: state.token,
            deviceId: state.deviceId,
            bookUid: bookUid,
          )
          .timeout(_timeout);
      if (result.items.isEmpty) return null;

      final remote = result.items.first;
      final remoteHash = readingProgressContentHash(remote);
      final local = await _source.getProgress(bookUid);
      final localHash =
          local == null ? null : readingProgressContentHash(local);
      if (localHash != remoteHash) {
        await _source.saveProgress(remote);
        await _saveHashes(<String, String>{bookUid: remoteHash});
        return remote;
      }

      await _saveHashes(<String, String>{bookUid: remoteHash});
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SyncResult> _pushBookOnExit(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return const SyncResult();

    try {
      final local = await _source.getProgress(bookUid);
      if (local == null) return const SyncResult();

      final localHash = readingProgressContentHash(local);
      if (config.syncedContentHashes[bookUid] == localHash) {
        return const SyncResult();
      }

      final result = await _push(config, [local]);
      if (result.accepted > 0) {
        await _saveHashes(<String, String>{bookUid: localHash});
      }
      return SyncResult(pushed: result.changed);
    } catch (_) {
      return const SyncResult();
    }
  }

  Future<SyncResult> _syncAllInternal() async {
    final config = _configStore.load();
    if (!config.isConfigured) return const SyncResult();

    var pushed = 0;
    var pulled = 0;

    try {
      var state = config;

      // 旧配置没有游标时先拉取服务器现有状态,只把本地独有内容推上去。
      if (state.cursor == null) {
        final baseline = await _pull(
          state,
          cursor: 0,
        );
        final baselineCursor = baseline.cursor;
        if (baselineCursor == null) {
          throw StateError('sync server does not support cursor pull');
        }

        final hashes = <String, String>{};
        for (final remote in baseline.items) {
          if (!await _source.hasBook(remote.bookUid)) continue;

          final remoteHash = readingProgressContentHash(remote);
          final local = await _source.getProgress(remote.bookUid);
          final localHash =
              local == null ? null : readingProgressContentHash(local);
          if (localHash != remoteHash) {
            await _source.saveProgress(remote);
            pulled++;
          }
          hashes[remote.bookUid] = remoteHash;
        }

        await _configStore.save(
          state.copyWith(
            cursor: baselineCursor,
            lastSyncAt: baseline.serverTime,
            syncedContentHashes: hashes,
          ),
        );
        state = _configStore.load();
      }

      final localItems = await _source.listAllProgress();
      final localHashes = <String, String>{};
      final changedItems = <ReadingProgress>[];
      for (final local in localItems) {
        final hash = readingProgressContentHash(local);
        localHashes[local.bookUid] = hash;
        if (state.syncedContentHashes[local.bookUid] != hash) {
          changedItems.add(local);
        }
      }

      if (changedItems.isNotEmpty) {
        final result = await _push(state, changedItems);
        pushed = result.changed;
        if (result.accepted == changedItems.length) {
          final hashes = <String, String>{
            ...state.syncedContentHashes,
            for (final item in changedItems)
              item.bookUid: localHashes[item.bookUid]!,
          };
          await _configStore.save(
            state.copyWith(syncedContentHashes: hashes),
          );
          state = _configStore.load();
        }
      }

      final result = await _pull(
        state,
        cursor: state.cursor ?? 0,
      );
      final nextCursor = result.cursor;
      if (nextCursor == null) {
        throw StateError('sync server did not return a cursor');
      }

      final hashes = <String, String>{...state.syncedContentHashes};
      for (final remote in result.items) {
        if (!await _source.hasBook(remote.bookUid)) continue;

        final remoteHash = readingProgressContentHash(remote);
        final local = await _source.getProgress(remote.bookUid);
        final localHash =
            local == null ? null : readingProgressContentHash(local);

        if (localHash == remoteHash) {
          hashes[remote.bookUid] = remoteHash;
          continue;
        }

        await _source.saveProgress(remote);
        hashes[remote.bookUid] = remoteHash;
        pulled++;
      }

      await _configStore.save(
        state.copyWith(
          cursor: nextCursor,
          lastSyncAt: result.serverTime,
          syncedContentHashes: hashes,
        ),
      );
      return SyncResult(pushed: pushed, pulled: pulled);
    } catch (_) {
      return SyncResult(pushed: pushed, pulled: pulled);
    }
  }

  Future<SyncPushResult> _push(
    SyncConfig config,
    List<ReadingProgress> items,
  ) {
    return _api
        .push(
          serverUrl: config.serverUrl,
          token: config.token,
          deviceId: config.deviceId,
          items: items,
        )
        .timeout(_timeout);
  }

  Future<SyncPullResult> _pull(
    SyncConfig config, {
    required int cursor,
  }) {
    return _api
        .pull(
          serverUrl: config.serverUrl,
          token: config.token,
          deviceId: config.deviceId,
          cursor: cursor,
        )
        .timeout(_timeout);
  }

  Future<void> _saveHashes(Map<String, String> updates) async {
    final current = _configStore.load();
    final hashes = <String, String>{
      ...current.syncedContentHashes,
      ...updates,
    };
    final next = current.copyWith(syncedContentHashes: hashes);
    await _configStore.save(next);
  }
}
