import 'dart:io';
import 'dart:typed_data';

import 'package:foundation_domain/domain.dart';

import 'book_cloud_ports.dart';
import 'files_backend.dart';
import 'library_api_client.dart';
import 'sync_ports.dart';

/// 书库云备份统计(供设置页展示)。
class CloudLibraryCounts {
  const CloudLibraryCounts({
    required this.backedUp,
    required this.pending,
    required this.cloudOnly,
  });

  /// 云端已有完整副本的书(含仅云端)。
  final int backedUp;

  /// 待上传(排队/失败重试)。
  final int pending;

  /// 本地无大文件、只有云端副本的书。
  final int cloudOnly;
}

/// 书单合并结果。
class CloudManifestResult {
  const CloudManifestResult({
    required this.added,
    required this.tombstones,
  });

  final int added;
  final int tombstones;
}

/// 书库云备份:上传原始文件+封面、释放本地冷书、按需取回、合并云端书单。
class BookCloudManager {
  BookCloudManager({
    required SyncConfigStore configStore,
    required LibraryApiClient api,
    required BookCloudLibraryPort library,
    required BookCloudFilesPort files,
    NetworkStatusPort network = const AlwaysAllowNetwork(),
  })  : _configStore = configStore,
        _api = api,
        _library = library,
        _files = files,
        _network = network;

  final SyncConfigStore _configStore;
  final LibraryApiClient _api;
  final BookCloudLibraryPort _library;
  final BookCloudFilesPort _files;
  final NetworkStatusPort _network;

  SyncConfig get config => _configStore.load();

  /// 更新并持久化同步配置(设置页开关用)。
  Future<void> updateConfig(SyncConfig Function(SyncConfig) transform) async {
    await _configStore.save(transform(_configStore.load()));
  }

  Future<CloudLibraryCounts> counts() async {
    final entries = await _library.listAllEntries();
    var backed = 0;
    var pending = 0;
    var cloudOnly = 0;
    for (final entry in entries) {
      if (entry.cloudStatus == CloudBackupStatus.synced) {
        backed++;
        if (!entry.isAvailableLocally) {
          cloudOnly++;
        }
      } else if (entry.cloudStatus == CloudBackupStatus.pending) {
        pending++;
      }
    }
    return CloudLibraryCounts(
      backedUp: backed,
      pending: pending,
      cloudOnly: cloudOnly,
    );
  }

  /// 导入成功后的自动备份入口。autoSync 关闭或仅 Wi-Fi 不满足时置为待传。
  Future<void> uploadBookAfterImport(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return;
    if (!config.autoSync) {
      return; // 关闭自动同步时保留 none,由"立即备份"手动处理。
    }
    if (!await _transferAllowed(config)) {
      await _library.setCloudStatus(bookUid, CloudBackupStatus.pending);
      return;
    }
    try {
      await _upload(config, bookUid);
    } catch (_) {
      await _library.setCloudStatus(bookUid, CloudBackupStatus.pending);
    }
  }

  /// 手动"立即备份":上传所有未同步的书(不受 Wi-Fi 限制)。返回成功数。
  Future<int> backupPendingBooks() async {
    final config = _configStore.load();
    if (!config.isConfigured) return 0;
    final entries = await _library.listAllEntries();
    var uploaded = 0;
    for (final entry in entries) {
      if (entry.format != 'epub') continue;
      if (entry.cloudStatus == CloudBackupStatus.synced) continue;
      if (!entry.isAvailableLocally) continue;
      try {
        await _upload(config, entry.bookUid);
        uploaded++;
      } catch (_) {
        await _library.setCloudStatus(entry.bookUid, CloudBackupStatus.pending);
      }
    }
    return uploaded;
  }

  /// 释放本地大文件(解析产物 + 原始文件),保留封面/进度/标注。
  Future<bool> evictBook(String bookUid) async {
    final entry = await _library.findByBookUid(bookUid);
    if (entry == null) return false;
    if (entry.cloudStatus != CloudBackupStatus.synced) return false;
    if (entry.pinLocal) return false;
    if (entry.format != 'epub') return false;
    await _files.evictBookFiles(bookUid);
    await _library.setEvicted(bookUid, evicted: true);
    return true;
  }

  /// 取回云端书:下载原始文件 → 重建解析产物 → 恢复本地状态。
  Future<void> restoreBook(
    String bookUid, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final config = _configStore.load();
    if (!config.isConfigured) {
      throw StateError('cloud backup is not configured');
    }
    final ext = await _filesExt(bookUid);
    final tempPath = await _files.createTempOriginalFile(bookUid, ext);
    final tempFile = File(tempPath);
    try {
      await _filesBackend(config).downloadOriginal(
            bookUid,
            tempFile,
            onProgress: onProgress,
          );
      await _files.restoreFromOriginal(
        bookUid: bookUid,
        originalPath: tempPath,
      );
      await _library.setEvicted(bookUid, evicted: false);
    } finally {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    }
  }

  /// 删除云端副本(书架删除对话框"同时删除云端副本")。
  Future<void> deleteCloudBook(String bookUid) async {
    final config = _configStore.load();
    if (!config.isConfigured) return;
    await _filesBackend(config).deleteOriginal(bookUid);
  }

  /// 合并云端书单:新设备出现"仅云端"条目;墓碑传播删除。
  Future<CloudManifestResult> applyManifest() async {
    final config = _configStore.load();
    if (!config.isConfigured) {
      return const CloudManifestResult(added: 0, tombstones: 0);
    }
    final (entries, serverTime) = await _api.fetchManifest(
      serverUrl: config.serverUrl,
      token: config.token,
      since: config.manifestSyncedAt ?? 0,
    );

    var added = 0;
    var tombstones = 0;
    for (final cloud in entries) {
      final local = await _library.findByBookUid(cloud.bookUid);
      if (cloud.isTombstone) {
        tombstones++;
        if (local == null) continue;
        if (local.isAvailableLocally) {
          // 本地还有完整副本:保留本地数据,仅取消云端标记。
          if (local.cloudStatus == CloudBackupStatus.synced) {
            await _library.setCloudStatus(
              cloud.bookUid,
              CloudBackupStatus.none,
            );
          }
        } else {
          // 纯云端条目:随墓碑从书架消失。
          await _library.deleteIndexEntry(cloud.bookUid);
        }
        continue;
      }

      if (local == null) {
        final entry = await _cloudOnlyEntry(cloud);
        await _library.upsertEntry(entry);
        added++;
        continue;
      }
      // 本地已有:云端确认存在副本时补状态(等待本地上传的 pending 不覆盖)。
      if (local.cloudStatus != CloudBackupStatus.pending &&
          local.cloudStatus != CloudBackupStatus.synced) {
        await _library.setCloudStatus(cloud.bookUid, CloudBackupStatus.synced);
      }
    }

    await _configStore.save(
      _configStore.load().copyWith(manifestSyncedAt: serverTime),
    );
    return CloudManifestResult(added: added, tombstones: tombstones);
  }

  /// 启动/回前台的自动维护:重试待传 → 合并书单 → 自动释放冷书。
  Future<void> runAutomaticMaintenance() async {
    final config = _configStore.load();
    if (!config.autoSyncActive) return;
    final allowed = await _transferAllowed(config);

    if (allowed) {
      final entries = await _library.listAllEntries();
      for (final entry in entries) {
        if (entry.cloudStatus != CloudBackupStatus.pending) continue;
        if (entry.format != 'epub' || !entry.isAvailableLocally) continue;
        try {
          await _upload(config, entry.bookUid);
        } catch (_) {
          // 保持 pending,下个触发点再试。
        }
      }
    }

    try {
      await applyManifest();
    } catch (_) {
      // 清单合并失败不阻塞本地使用。
    }

    if (config.autoEvictEnabled && allowed) {
      await autoEvictOldBooks();
    }
  }

  /// 自动释放 N 天未读的书(仅 epub、已备份、未固定)。
  Future<int> autoEvictOldBooks() async {
    final config = _configStore.load();
    if (!config.autoEvictEnabled) return 0;
    final threshold = DateTime.now().subtract(Duration(days: config.autoEvictDays));
    final entries = await _library.listAllEntries();
    var evicted = 0;
    for (final entry in entries) {
      if (entry.cloudStatus != CloudBackupStatus.synced) continue;
      if (entry.pinLocal || !entry.isAvailableLocally) continue;
      if (entry.format != 'epub') continue;
      final reference = entry.lastOpenedAt ?? entry.importedAt;
      if (reference.isAfter(threshold)) continue;
      if (await evictBook(entry.bookUid)) {
        evicted++;
      }
    }
    return evicted;
  }

  Future<bool> _transferAllowed(SyncConfig config) async {
    if (!config.wifiOnly) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return _network.canTransfer;
  }

  /// 书文件后端按当前配置解析(设置变更后无需重建 manager)。
  BookFilesBackend _filesBackend(SyncConfig config) =>
      resolveFilesBackend(config, _api);

  Future<void> _upload(SyncConfig config, String bookUid) async {
    final entry = await _library.findByBookUid(bookUid);
    if (entry == null) return;
    final original = await _files.originalFile(bookUid);
    if (original == null) return;

    final ext = original.uri.pathSegments.last
        .split('.')
        .last
        .toLowerCase();
    await _filesBackend(config).uploadOriginal(bookUid, original, ext);

    final cover = await _files.coverFile(bookUid);
    Uint8List? coverBytes;
    String? coverExt;
    if (cover != null) {
      coverBytes = await cover.readAsBytes();
      coverExt = cover.uri.pathSegments.last.split('.').last.toLowerCase();
    }
    await _api.announce(
      serverUrl: config.serverUrl,
      token: config.token,
      bookUid: bookUid,
      fingerprint: entry.fingerprint,
      title: entry.title,
      authors: entry.authors,
      format: entry.format,
      sizeBytes: entry.format == 'epub' ? await original.length() : 0,
      importedAt: entry.importedAt.millisecondsSinceEpoch,
      coverExt: coverExt,
      coverBytes: coverBytes,
    );
    await _library.setCloudStatus(bookUid, CloudBackupStatus.synced);
  }

  Future<String> _filesExt(String bookUid) async {
    final original = await _files.originalFile(bookUid);
    if (original != null) {
      return original.uri.pathSegments.last.split('.').last.toLowerCase();
    }
    return 'epub';
  }

  Future<LibraryIndexEntry> _cloudOnlyEntry(CloudBookManifestEntry cloud) async {
    final authors = cloud.authors;
    String? coverRelPath;
    if (cloud.coverExt.isNotEmpty) {
      try {
        final bytes = await _api.downloadCover(
          serverUrl: config.serverUrl,
          token: config.token,
          bookUid: cloud.bookUid,
        );
        await _files.saveCoverBytes(cloud.bookUid, bytes, cloud.coverExt);
        coverRelPath = 'cover.${cloud.coverExt}';
      } catch (_) {
        coverRelPath = null; // 封面缺失不阻塞条目落库。
      }
    }
    final now = DateTime.now();
    return LibraryIndexEntry(
      bookUid: cloud.bookUid,
      fingerprint: cloud.fingerprint,
      format: cloud.format,
      title: cloud.title,
      authors: authors,
      coverRelPath: coverRelPath,
      importedAt: DateTime.fromMillisecondsSinceEpoch(cloud.importedAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(cloud.updatedAt),
      cloudStatus: CloudBackupStatus.synced,
      evictedAt: now,
    );
  }
}
