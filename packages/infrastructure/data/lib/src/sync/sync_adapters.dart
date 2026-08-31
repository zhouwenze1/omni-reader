import 'package:flutter/foundation.dart';
import 'package:foundation_domain/domain.dart';
import 'package:hive/hive.dart';
import 'package:services_sync/services_sync.dart';

/// 同步配置的 Hive 实现,复用 settings_box。
class HiveSyncConfigStore implements SyncConfigStore {
  HiveSyncConfigStore(this._box);

  static const String _key = 'settings.sync.v1';

  final Box<dynamic> _box;

  @override
  SyncConfig load() {
    final raw = _box.get(_key);
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry('$k', v));
      final serverUrl = map['serverUrl']?.toString() ?? '';
      final token = map['token']?.toString() ?? '';
      final deviceId = map['deviceId']?.toString() ?? '';
      final lastSyncAtRaw = map['lastSyncAt'];
      final lastSyncAt = lastSyncAtRaw is int
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncAtRaw)
          : null;
      return SyncConfig(
        serverUrl: serverUrl,
        token: token,
        deviceId: deviceId,
        lastSyncAt: lastSyncAt,
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
      'lastSyncAt': config.lastSyncAt?.millisecondsSinceEpoch,
    });
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
