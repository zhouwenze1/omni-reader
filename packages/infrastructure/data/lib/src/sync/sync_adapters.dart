import 'package:flutter/foundation.dart';
import 'package:foundation_domain/domain.dart';
import 'package:hive/hive.dart';
import 'package:services_sync/services_sync.dart';

/// 同步配置的 Hive 实现,复用 settings_box。
class HiveSyncConfigStore implements SyncConfigStore {
  HiveSyncConfigStore(this._box);

  static const String _key = 'settings.sync.v2';
  static const String _legacyKey = 'settings.sync.v1';

  final Box<dynamic> _box;

  @override
  SyncConfig load() {
    final raw = _box.get(_key) ?? _box.get(_legacyKey);
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry('$k', v));
      final serverUrl = map['serverUrl']?.toString() ?? '';
      final token = map['token']?.toString() ?? '';
      final deviceId = map['deviceId']?.toString() ?? '';
      final lastSyncAtRaw = map['lastSyncAt'];
      final lastSyncAt = lastSyncAtRaw is int
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncAtRaw, isUtc: true)
          : null;
      final cursorRaw = map['cursor'];
      final cursor = cursorRaw is num ? cursorRaw.toInt() : null;
      final manifestSyncedAtRaw = map['manifestSyncedAt'];
      final manifestSyncedAt =
          manifestSyncedAtRaw is num ? manifestSyncedAtRaw.toInt() : null;
      final hashesRaw = map['syncedContentHashes'];
      final syncedContentHashes = hashesRaw is Map
          ? <String, String>{
              for (final entry in hashesRaw.entries)
                '${entry.key}': '${entry.value}',
            }
          : const <String, String>{};
      final entityCursorsRaw = map['entityCursors'];
      final entityCursors = entityCursorsRaw is Map
          ? <String, int>{
              for (final entry in entityCursorsRaw.entries)
                '${entry.key}': (entry.value as num).toInt(),
            }
          : const <String, int>{};
      final styleSyncedHash = map['styleSyncedHash']?.toString();
      final styleSyncedAt = map['styleSyncedAt'] is num
          ? (map['styleSyncedAt'] as num).toInt()
          : null;
      final statsPushedUntil = map['statsPushedUntil'] is num
          ? (map['statsPushedUntil'] as num).toInt()
          : null;
      return SyncConfig(
        serverUrl: serverUrl,
        token: token,
        deviceId: deviceId,
        autoSync: map['autoSync'] is bool ? map['autoSync'] as bool : true,
        wifiOnly: map['wifiOnly'] is bool ? map['wifiOnly'] as bool : true,
        autoEvictEnabled: map['autoEvictEnabled'] is bool
            ? map['autoEvictEnabled'] as bool
            : false,
        autoEvictDays:
            map['autoEvictDays'] is num ? (map['autoEvictDays'] as num).toInt() : 30,
        lastSyncAt: lastSyncAt,
        cursor: cursor,
        manifestSyncedAt: manifestSyncedAt,
        syncedContentHashes: syncedContentHashes,
        syncAnnotations:
            map['syncAnnotations'] is bool ? map['syncAnnotations'] as bool : true,
        syncSettings:
            map['syncSettings'] is bool ? map['syncSettings'] as bool : true,
        syncStats: map['syncStats'] is bool ? map['syncStats'] as bool : true,
        entityCursors: entityCursors,
        styleSyncedHash: styleSyncedHash,
        styleSyncedAt: styleSyncedAt,
        statsPushedUntil: statsPushedUntil,
        webdavEnabled:
            map['webdavEnabled'] is bool ? map['webdavEnabled'] as bool : false,
        webdavUrl: map['webdavUrl']?.toString() ?? '',
        webdavUsername: map['webdavUsername']?.toString() ?? '',
        webdavPassword: map['webdavPassword']?.toString() ?? '',
      );
    }
    return const SyncConfig(serverUrl: '', token: '', deviceId: '');
  }

  @override
  Future<void> save(SyncConfig config) {
    return _box.put(_key, {
      'serverUrl': config.serverUrl,
      'token': config.token,
      'deviceId': config.deviceId,
      'autoSync': config.autoSync,
      'wifiOnly': config.wifiOnly,
      'autoEvictEnabled': config.autoEvictEnabled,
      'autoEvictDays': config.autoEvictDays,
      'lastSyncAt': config.lastSyncAt?.millisecondsSinceEpoch,
      'cursor': config.cursor,
      'manifestSyncedAt': config.manifestSyncedAt,
      'syncedContentHashes': config.syncedContentHashes,
      'syncAnnotations': config.syncAnnotations,
      'syncSettings': config.syncSettings,
      'syncStats': config.syncStats,
      'entityCursors': config.entityCursors,
      'styleSyncedHash': config.styleSyncedHash,
      'styleSyncedAt': config.styleSyncedAt,
      'statsPushedUntil': config.statsPushedUntil,
      'webdavEnabled': config.webdavEnabled,
      'webdavUrl': config.webdavUrl,
      'webdavUsername': config.webdavUsername,
      'webdavPassword': config.webdavPassword,
    });
  }
}

/// 标注同步端口:基于 AnnotationRepository(jsonl 按书整读整写)。
///
/// 本地删除是真删(jsonl 重写),删除传播靠这里 diff 出的墓碑队列:
/// 每次 replaceAnnotations 与旧列表对比,消失的 id 记为墓碑,
/// 同步推送成功后确认移除。
class AnnotationSyncSourceImpl implements AnnotationSyncSource {
  AnnotationSyncSourceImpl(this._repository, this._box);

  final AnnotationRepository _repository;
  final Box<dynamic> _box;

  static const String _tombstoneKey = 'sync.annotation.tombstones';

  @override
  Future<List<Annotation>> listAnnotations(String bookUid) {
    return _repository.listAnnotations(bookUid);
  }

  @override
  Future<void> replaceAnnotations(
    String bookUid,
    List<Annotation> annotations,
  ) async {
    // diff 旧列表,把消失的 id 记为删除墓碑(时间戳为删除动作发生时刻)。
    final previousIds = (await _repository.listAnnotations(bookUid))
        .map((a) => a.id)
        .toSet();
    final nextIds = annotations.map((a) => a.id).toSet();
    final removed = previousIds.difference(nextIds);
    await _repository.replaceAnnotations(bookUid, annotations);
    if (removed.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final tombstones = <String, dynamic>{..._loadTombstones()};
    for (final id in removed) {
      tombstones[id] = {'id': id, 'bookUid': bookUid, 'updatedAt': now};
    }
    await _box.put(_tombstoneKey, tombstones);
  }

  @override
  Future<List<AnnotationTombstone>> pendingAnnotationTombstones() async {
    return [
      for (final value in _loadTombstones().values)
        AnnotationTombstone(
          id: '${value['id']}',
          bookUid: '${value['bookUid']}',
          updatedAt: (value['updatedAt'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<void> confirmTombstones(List<String> ids) async {
    if (ids.isEmpty) return;
    final tombstones = _loadTombstones()..removeWhere((id, _) => ids.contains(id));
    await _box.put(_tombstoneKey, tombstones);
  }

  Map<String, dynamic> _loadTombstones() {
    final raw = _box.get(_tombstoneKey);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(
            '$k',
            v is Map ? v.map((k2, v2) => MapEntry('$k2', v2)) : <String, dynamic>{},
          ));
    }
    return <String, dynamic>{};
  }
}

/// 阅读设置同步端口:基于 SettingsRepository。
class SettingsSyncSourceImpl implements SettingsSyncSource {
  SettingsSyncSourceImpl(this._repository);

  final SettingsRepository _repository;

  @override
  Future<ReaderSettings> getReaderSettings() {
    return _repository.getReaderSettings();
  }

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) {
    return _repository.saveReaderSettings(settings);
  }
}

/// 统计同步端口:基于 ReadingStatsRepository。
class StatsSyncSourceImpl implements StatsSyncSource {
  StatsSyncSourceImpl(this._repository);

  final ReadingStatsRepository _repository;

  @override
  Future<List<ReadingSessionRecord>> sessionsSince(int sinceMs) {
    return _repository.sessionsSince(sinceMs);
  }

  @override
  Future<bool> hasSession({
    required String deviceId,
    required int startedAtMs,
  }) {
    return _repository.hasSession(
      deviceId: deviceId,
      startedAtMs: startedAtMs,
    );
  }

  @override
  Future<void> insertSyncedSession(ReadingSessionRecord record) {
    return _repository.insertSyncedSession(record);
  }
}

/// 进度数据端口:基于 ProgressRepository + 书架索引实现。
class ProgressSyncSourceImpl implements ProgressSyncSource {
  ProgressSyncSourceImpl({
    required ProgressRepository progressRepository,
    required BookRepository bookRepository,
  })  : _progressRepository = progressRepository,
        _bookRepository = bookRepository;

  final ProgressRepository _progressRepository;
  final BookRepository _bookRepository;

  @override
  Future<ReadingProgress?> getProgress(String bookUid) {
    return _progressRepository.getProgress(bookUid);
  }

  @override
  Future<List<ReadingProgress>> listAllProgress() {
    return _progressRepository.listProgress();
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) {
    return _progressRepository.saveProgress(progress);
  }

  @override
  Future<bool> hasBook(String bookUid) async {
    try {
      return await _bookRepository.getBook(bookUid) != null;
    } catch (error) {
      debugPrint('[sync][hasBook.error] $error');
      return false;
    }
  }
}
