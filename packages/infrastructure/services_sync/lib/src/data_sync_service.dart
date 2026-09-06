import 'dart:convert';

import 'package:foundation_domain/domain.dart';

import 'progress_sync_service.dart';
import 'sync_api_client.dart';
import 'sync_ports.dart';

/// 标注/阅读设置/阅读统计同步(v2 多实体)。
///
/// 与进度同步共用服务器与 token,按实体独立游标增量拉取;推送侧依赖服务端
/// 内容指纹去重,重复推送幂等。冲突语义:标注按 updatedAt LWW + 墓碑删除,
/// 设置整包 LWW,统计按 (deviceId, startedAt) 并集合并。
class DataSyncService {
  DataSyncService({
    required SyncApiClient api,
    required SyncConfigStore configStore,
    required ProgressSyncSource progress,
    required AnnotationSyncSource annotations,
    required SettingsSyncSource settings,
    required StatsSyncSource stats,
  })  : _api = api,
        _configStore = configStore,
        _progress = progress,
        _annotations = annotations,
        _settings = settings,
        _stats = stats;

  final SyncApiClient _api;
  final SyncConfigStore _configStore;
  final ProgressSyncSource _progress;
  final AnnotationSyncSource _annotations;
  final SettingsSyncSource _settings;
  final StatsSyncSource _stats;

  static const String _settingStyleKey = 'reader_style';
  static const Duration _timeout = Duration(seconds: 8);

  /// 读取当前配置(设置页开关/WebDAV 配置用)。
  SyncConfig getConfig() => _configStore.load();

  /// 保存配置。内容开关/WebDAV 配置不属于服务器身份,不重置同步基线。
  Future<void> saveConfig(SyncConfig config) => _configStore.save(config);

  /// 打开图书时拉取该书的标注变化(快速路径,失败静默)。
  Future<void> pullBookOnOpen(String bookUid) async {
    final config = _configStore.load();
    if (!config.autoSyncActive || !config.syncAnnotations) return;
    try {
      await _pullAnnotations(config, bookUids: {bookUid});
    } catch (_) {
      // 拉取失败不阻塞开书,下个触发点会重试。
    }
  }

  /// 阅读页退出后:推送该书标注 + 统计会话增量 + 阅读设置。
  Future<SyncResult> pushOnReaderExit(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return const SyncResult();
    var pushed = 0;
    try {
      if (config.syncAnnotations) {
        pushed += await _pushBookAnnotations(config, bookUid);
      }
      if (config.syncStats) {
        pushed += await _pushStats(config);
      }
      if (config.syncSettings) {
        pushed += await _pushSettings(config);
      }
      return SyncResult(pushed: pushed);
    } catch (error) {
      return SyncResult(pushed: pushed, error: error.toString());
    }
  }

  /// 应用启动/手动同步:推送全部标注/统计/设置,再按游标拉取三实体变化。
  Future<SyncResult> syncAll() async {
    final config = _configStore.load();
    if (!config.isConfigured) return const SyncResult();
    var pushed = 0;
    var pulled = 0;
    try {
      if (config.syncAnnotations) {
        for (final bookUid in (await _progress.listAllProgress())
            .map((p) => p.bookUid)) {
          pushed += await _pushBookAnnotations(config, bookUid);
        }
        pulled += await _pullAnnotations(config);
      }
      if (config.syncSettings) {
        pushed += await _pushSettings(config);
        pulled += await _pullSettings(config);
      }
      if (config.syncStats) {
        pushed += await _pushStats(config);
        pulled += await _pullStats(config);
      }
      return SyncResult(pushed: pushed, pulled: pulled);
    } catch (error) {
      return SyncResult(pushed: pushed, pulled: pulled, error: error.toString());
    }
  }

  // ---- 标注 ----

  /// 推送一本书的全部标注与该书删除墓碑;服务端按指纹去重,重复推送幂等。
  Future<int> _pushBookAnnotations(SyncConfig config, String bookUid) async {
    if (!await _progress.hasBook(bookUid)) return 0;
    final list = await _annotations.listAnnotations(bookUid);
    final tombstones = (await _annotations.pendingAnnotationTombstones())
        .where((t) => t.bookUid == bookUid)
        .toList();
    if (list.isEmpty && tombstones.isEmpty) return 0;
    final result = await _api
        .pushEntity(
          serverUrl: config.serverUrl,
          token: config.token,
          deviceId: config.deviceId,
          entity: 'annotation',
          items: [
            for (final annotation in list)
              {
                'key': annotation.id,
                'payload': annotation.toJson(),
                'updatedAt': annotation.updatedAt.millisecondsSinceEpoch,
              },
            for (final tombstone in tombstones)
              {
                'key': tombstone.id,
                'payload': {'bookUid': bookUid},
                'updatedAt': tombstone.updatedAt,
                'deleted': true,
              },
          ],
        )
        .timeout(_timeout);
    if (result.accepted > 0) {
      await _annotations.confirmTombstones(
        tombstones.map((t) => t.id).toList(),
      );
    }
    return result.changed;
  }

  Future<int> _pullAnnotations(
    SyncConfig config, {
    Set<String>? bookUids,
  }) async {
    final cursor = config.entityCursors['annotation'] ?? 0;
    final result = await _api
        .pullEntity(
          serverUrl: config.serverUrl,
          token: config.token,
          entity: 'annotation',
          cursor: cursor,
        )
        .timeout(_timeout);

    // 按书分组后整书合并(LWW + 墓碑)。
    final byBook = <String, List<EntitySyncItem>>{};
    for (final item in result.items) {
      final bookUid = '${item.payload['bookUid'] ?? ''}';
      if (bookUid.isEmpty) continue;
      byBook.putIfAbsent(bookUid, () => []).add(item);
    }
    var applied = 0;
    for (final entry in byBook.entries) {
      if (bookUids != null && !bookUids.contains(entry.key)) continue;
      if (!await _progress.hasBook(entry.key)) continue;
      applied += await _mergeBookAnnotations(entry.key, entry.value);
    }
    await _saveCursor('annotation', result.cursor);
    return applied;
  }

  Future<int> _mergeBookAnnotations(
    String bookUid,
    List<EntitySyncItem> items,
  ) async {
    final local = {
      for (final annotation in await _annotations.listAnnotations(bookUid))
        annotation.id: annotation,
    };
    var changed = false;
    for (final item in items) {
      if (item.deleted) {
        final existing = local[item.key];
        // 删除也是 LWW:对端删除时间新于本地标注修改时间才删。
        if (existing != null &&
            !existing.updatedAt.isAfter(DateTime.fromMillisecondsSinceEpoch(
              item.updatedAt,
            ))) {
          local.remove(item.key);
          changed = true;
        }
        continue;
      }
      final remote = Annotation.fromJson(item.payload);
      final existing = local[item.key];
      if (existing == null || remote.updatedAt.isAfter(existing.updatedAt)) {
        local[item.key] = remote;
        changed = true;
      }
    }
    if (!changed) return 0;
    final merged = local.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _annotations.replaceAnnotations(bookUid, merged);
    return items.length;
  }

  // ---- 阅读设置(整包 LWW) ----

  Future<int> _pushSettings(SyncConfig config) async {
    final json = (await _settings.getReaderSettings()).toJson();
    final hash = canonicalJsonHash(json);
    if (config.styleSyncedHash == hash) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await _api
        .pushEntity(
          serverUrl: config.serverUrl,
          token: config.token,
          deviceId: config.deviceId,
          entity: 'setting',
          items: [
            {'key': _settingStyleKey, 'payload': json, 'updatedAt': now},
          ],
        )
        .timeout(_timeout);
    if (result.accepted > 0) {
      await _configStore.save(
        _configStore.load().copyWith(
              styleSyncedHash: hash,
              styleSyncedAt: now,
            ),
      );
      return 1;
    }
    return 0;
  }

  Future<int> _pullSettings(SyncConfig config) async {
    final cursor = config.entityCursors['setting'] ?? 0;
    final result = await _api
        .pullEntity(
          serverUrl: config.serverUrl,
          token: config.token,
          entity: 'setting',
          cursor: cursor,
        )
        .timeout(_timeout);

    for (final item in result.items) {
      if (item.key != _settingStyleKey) continue;
      final knownAt = config.styleSyncedAt ?? 0;
      if (item.updatedAt <= knownAt) continue;
      final hash = canonicalJsonHash(item.payload);
      if (hash == config.styleSyncedHash) {
        await _configStore.save(
          _configStore.load().copyWith(styleSyncedAt: item.updatedAt),
        );
        continue;
      }
      await _settings.saveReaderSettings(ReaderSettings.fromJson(item.payload));
      await _configStore.save(
        _configStore.load().copyWith(
              styleSyncedHash: hash,
              styleSyncedAt: item.updatedAt,
            ),
      );
    }
    await _saveCursor('setting', result.cursor);
    return result.items.length;
  }

  // ---- 阅读统计((deviceId, startedAt) 并集) ----

  Future<int> _pushStats(SyncConfig config) async {
    final records = await _stats.sessionsSince(config.statsPushedUntil ?? 0);
    if (records.isEmpty) return 0;
    final result = await _api
        .pushEntity(
          serverUrl: config.serverUrl,
          token: config.token,
          deviceId: config.deviceId,
          entity: 'stat',
          items: [
            for (final record in records)
              {
                'key': '${record.deviceId}:${record.startedAtMs}',
                'payload': record.toJson(),
                'updatedAt': record.startedAtMs,
              },
          ],
        )
        .timeout(_timeout);
    if (result.accepted > 0) {
      await _configStore.save(
        _configStore.load().copyWith(
          statsPushedUntil: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    return result.changed;
  }

  Future<int> _pullStats(SyncConfig config) async {
    final cursor = config.entityCursors['stat'] ?? 0;
    final result = await _api
        .pullEntity(
          serverUrl: config.serverUrl,
          token: config.token,
          entity: 'stat',
          cursor: cursor,
        )
        .timeout(_timeout);

    var inserted = 0;
    for (final item in result.items) {
      if (item.deleted) continue;
      final record = ReadingSessionRecord.fromJson(item.payload);
      if (record.startedAtMs <= 0) continue;
      final exists = await _stats.hasSession(
        deviceId: record.deviceId,
        startedAtMs: record.startedAtMs,
      );
      if (exists) continue;
      await _stats.insertSyncedSession(record);
      inserted++;
    }
    await _saveCursor('stat', result.cursor);
    return inserted;
  }

  Future<void> _saveCursor(String entity, int cursor) async {
    final current = _configStore.load();
    final cursors = <String, int>{...current.entityCursors, entity: cursor};
    await _configStore.save(current.copyWith(entityCursors: cursors));
  }
}

/// 规范化 JSON 指纹:递归排序 map 键后序列化,两端计算结果一致。
String canonicalJsonHash(Map<String, dynamic> json) {
  return jsonEncode(_canonical(json));
}

dynamic _canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((k) => '$k').toList()..sort();
    return {
      for (final key in keys) key: _canonical(value[key]),
    };
  }
  if (value is List) {
    return [for (final item in value) _canonical(item)];
  }
  return value;
}
