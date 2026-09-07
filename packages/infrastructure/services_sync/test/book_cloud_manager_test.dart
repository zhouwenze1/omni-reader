import 'dart:io';

import 'package:foundation_domain/domain.dart';
import 'package:services_sync/services_sync.dart';
import 'package:test/test.dart';

class _FakeConfigStore implements SyncConfigStore {
  _FakeConfigStore(this._config);

  SyncConfig _config;

  @override
  SyncConfig load() => _config;

  @override
  Future<void> save(SyncConfig config) async {
    _config = config;
  }
}

class _FakeLibrary implements BookCloudLibraryPort {
  final Map<String, LibraryIndexEntry> entries = {};

  @override
  Future<LibraryIndexEntry?> findByBookUid(String bookUid) async =>
      entries[bookUid];

  @override
  Future<List<LibraryIndexEntry>> listAllEntries() async =>
      entries.values.toList();

  @override
  Future<void> upsertEntry(LibraryIndexEntry entry) async {
    entries[entry.bookUid] = entry;
  }

  @override
  Future<void> setCloudStatus(String bookUid, CloudBackupStatus status) async {
    entries[bookUid] = entries[bookUid]!.copyWith(cloudStatus: status);
  }

  @override
  Future<void> setEvicted(String bookUid, {required bool evicted}) async {
    entries[bookUid] = entries[bookUid]!.copyWith(
      evictedAt: evicted ? DateTime.fromMillisecondsSinceEpoch(1) : null,
    );
  }

  @override
  Future<void> setPinLocal(String bookUid, {required bool pinned}) async {
    entries[bookUid] = entries[bookUid]!.copyWith(pinLocal: pinned);
  }

  @override
  Future<void> deleteIndexEntry(String bookUid) async {
    entries.remove(bookUid);
  }
}

class _FakeFiles implements BookCloudFilesPort {
  @override
  Future<File?> originalFile(String bookUid) async => null;

  @override
  Future<File?> coverFile(String bookUid) async => null;

  @override
  Future<void> saveCoverBytes(
    String bookUid,
    List<int> bytes,
    String ext,
  ) async {}

  @override
  Future<void> evictBookFiles(String bookUid) async {
    evicted.add(bookUid);
  }

  final List<String> evicted = [];

  @override
  Future<bool> hasLocalArtifacts(String bookUid) async => true;

  @override
  Future<String> createTempOriginalFile(String bookUid, String ext) async =>
      '/tmp/$bookUid.$ext';

  @override
  Future<void> restoreFromOriginal({
    required String bookUid,
    required String originalPath,
  }) async {}
}

class _FakeApi extends LibraryApiClient {
  _FakeApi(this.manifestEntries);

  List<CloudBookManifestEntry> manifestEntries;
  int? fetchedSince;

  @override
  Future<(List<CloudBookManifestEntry>, int)> fetchManifest({
    required String serverUrl,
    required String token,
    int since = 0,
  }) async {
    fetchedSince = since;
    return (manifestEntries, 1000);
  }
}

LibraryIndexEntry localEntry(String uid,
    {CloudBackupStatus status = CloudBackupStatus.none}) {
  return LibraryIndexEntry(
    bookUid: uid,
    fingerprint: 'fp-$uid',
    format: 'epub',
    title: uid,
    authors: const [],
    importedAt: DateTime.fromMillisecondsSinceEpoch(10),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(10),
    cloudStatus: status,
  );
}

CloudBookManifestEntry cloudEntry(
  String uid, {
  int? deletedAt,
  String fingerprint = '',
}) {
  return CloudBookManifestEntry(
    bookUid: uid,
    fingerprint: fingerprint,
    title: uid,
    authorsJson: '[]',
    format: 'epub',
    sizeBytes: 1,
    coverExt: '',
    importedAt: 10,
    updatedAt: 20,
    deletedAt: deletedAt,
  );
}

void main() {
  test('applyManifest 为本地没有的书插入仅云端条目', () async {
    final store = _FakeConfigStore(const SyncConfig(
      serverUrl: 'http://x',
      token: 't',
      deviceId: 'd',
      manifestSyncedAt: 5,
    ));
    final library = _FakeLibrary();
    final api = _FakeApi([cloudEntry('cloud-1', fingerprint: 'fp-cloud-1')]);
    final manager = BookCloudManager(
      configStore: store,
      api: api,
      library: library,
      files: _FakeFiles(),
    );

    final result = await manager.applyManifest();

    expect(result.added, 1);
    expect(api.fetchedSince, 5);
    final entry = library.entries['cloud-1']!;
    expect(entry.cloudStatus, CloudBackupStatus.synced);
    expect(entry.isAvailableLocally, isFalse);
    expect(entry.fingerprint, 'fp-cloud-1');
    expect(store._config.manifestSyncedAt, 1000);
  });

  test('applyManifest 墓碑删除纯云端条目,但保留本地完整副本', () async {
    final store = _FakeConfigStore(const SyncConfig(
      serverUrl: 'http://x',
      token: 't',
      deviceId: 'd',
    ));
    final library = _FakeLibrary()
      ..entries['local-1'] = localEntry('local-1')
      ..entries['cloud-1'] = localEntry('cloud-1').copyWith(
        evictedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );
    final api = _FakeApi([
      cloudEntry('local-1', deletedAt: 99),
      cloudEntry('cloud-1', deletedAt: 99),
    ]);
    final manager = BookCloudManager(
      configStore: store,
      api: api,
      library: library,
      files: _FakeFiles(),
    );

    final result = await manager.applyManifest();

    expect(result.tombstones, 2);
    // 本地完整副本保留,云端标记取消。
    expect(library.entries['local-1'], isNotNull);
    expect(library.entries['local-1']!.cloudStatus, CloudBackupStatus.none);
    // 纯云端条目随墓碑消失。
    expect(library.entries.containsKey('cloud-1'), isFalse);
  });

  test('evictBook 仅在已备份/未固定/epub 时释放', () async {
    final files = _FakeFiles();
    final library = _FakeLibrary()
      ..entries['a'] = localEntry('a', status: CloudBackupStatus.synced)
      ..entries['b'] = localEntry('b', status: CloudBackupStatus.pending)
      ..entries['c'] = localEntry('c', status: CloudBackupStatus.synced)
          .copyWith(pinLocal: true)
      ..entries['d'] = localEntry('d', status: CloudBackupStatus.synced)
          .copyWith(format: 'pdf');
    final manager = BookCloudManager(
      configStore: _FakeConfigStore(const SyncConfig(
        serverUrl: 'http://x',
        token: 't',
        deviceId: 'd',
      )),
      api: _FakeApi(const []),
      library: library,
      files: files,
    );

    expect(await manager.evictBook('a'), isTrue);
    expect(await manager.evictBook('b'), isFalse); // 未备份
    expect(await manager.evictBook('c'), isFalse); // 已固定
    expect(await manager.evictBook('d'), isFalse); // 非 epub
    expect(files.evicted, ['a']);
    expect(library.entries['a']!.isAvailableLocally, isFalse);
  });

  test('autoEvictOldBooks 释放超过阈值未读的书', () async {
    final files = _FakeFiles();
    final now = DateTime.now();
    final library = _FakeLibrary()
      ..entries['old'] = localEntry('old', status: CloudBackupStatus.synced)
          .copyWith(lastOpenedAt: now.subtract(const Duration(days: 60)))
      ..entries['fresh'] = localEntry('fresh', status: CloudBackupStatus.synced)
          .copyWith(lastOpenedAt: now.subtract(const Duration(days: 1)));
    final manager = BookCloudManager(
      configStore: _FakeConfigStore(const SyncConfig(
        serverUrl: 'http://x',
        token: 't',
        deviceId: 'd',
        autoEvictEnabled: true,
        autoEvictDays: 30,
      )),
      api: _FakeApi(const []),
      library: library,
      files: files,
    );

    final evicted = await manager.autoEvictOldBooks();

    expect(evicted, 1);
    expect(files.evicted, ['old']);
  });
}
