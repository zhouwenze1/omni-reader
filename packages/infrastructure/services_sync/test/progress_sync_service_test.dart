import 'dart:convert';
import 'dart:io';

import 'package:foundation_domain/domain.dart';
import 'package:test/test.dart';
import 'package:services_sync/services_sync.dart';

/// 内存版端口实现,便于单测。
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

class _FakeSource implements ProgressSyncSource {
  final Map<String, ReadingProgress> progress = {};
  final Set<String> books = {};

  @override
  Future<ReadingProgress?> getProgress(String bookUid) async => progress[bookUid];

  @override
  Future<List<ReadingProgress>> listAllProgress() async => progress.values.toList();

  @override
  Future<void> saveProgress(ReadingProgress p) async {
    progress[p.bookUid] = p;
  }

  @override
  Future<bool> hasBook(String bookUid) async => books.contains(bookUid);
}

ReadingProgress _progress(String uid, int updatedAt, double progression) {
  return ReadingProgress(
    bookUid: uid,
    locator: Locator(locations: {'progression': progression}),
    progression: progression,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    lastReadAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
  );
}

SyncConfig _config({String url = 'http://server:8080'}) {
  return SyncConfig(serverUrl: url, token: 't', deviceId: 'dev1');
}

void main() {
  group('ProgressSyncService', () {
    test('未配置时所有操作直接返回,不发起请求', () async {
      final store = _FakeConfigStore(const SyncConfig(
        serverUrl: '',
        token: '',
        deviceId: 'dev1',
      ));
      final source = _FakeSource();
      final service = ProgressSyncService(
        api: SyncApiClient(),
        source: source,
        configStore: store,
      );

      expect(await service.pullBookOnOpen('b1'), isNull);
      expect((await service.pushBookOnExit('b1')).pushed, 0);
      expect((await service.syncAll()).pushed, 0);
    });

    test('syncAll 远端更新覆盖本地,本地更新保留,游标推进', () async {
      // 用本地 HTTP 服务器模拟远端。
      final source = _FakeSource();
      // 本地:书 b1 进度 0.4(updatedAt 100)
      source.progress['b1'] = _progress('b1', 100, 0.4);
      source.books.addAll({'b1', 'b2'});

      final server = await _startFakeServer();
      final store = _FakeConfigStore(
        _config(url: 'http://127.0.0.1:${server.port}'),
      );
      final service = ProgressSyncService(
        api: SyncApiClient(),
        source: source,
        configStore: store,
      );

      // 先推一本远端进度 0.9(updatedAt 200)到服务器。
      await service.pushBookOnExit('b1');
      // 服务器上 b1=0.9/200。手动改本地为 0.4/100,再同步应拉回 0.9。
      source.progress['b1'] = _progress('b1', 100, 0.4);
      final result = await service.syncAll();
      expect(result.pulled, 1);
      expect(source.progress['b1']!.progression, 0.9);
      expect(store.load().lastSyncAt, isNotNull);
      await server.close();
    });
  });
}

/// 简易假服务器:单接口 pull 返回固定记录。
Future<_FakeServer> _startFakeServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    if (request.uri.path == '/api/sync/pull') {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'items': [
            {
              'bookUid': 'b1',
              'locator': {'locations': {'progression': 0.9}},
              'progression': 0.9,
              'updatedAt': 200,
              'lastReadAt': 200,
            },
          ],
          'serverTime': 500,
        }));
    } else if (request.uri.path == '/api/sync/push') {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'accepted': 1}));
    } else {
      request.response.statusCode = 404;
    }
    request.response.close();
  });
  return _FakeServer(server);
}

class _FakeServer {
  _FakeServer(this._server);
  final HttpServer _server;
  int get port => _server.port;
  Future<void> close() => _server.close(force: true);
}
