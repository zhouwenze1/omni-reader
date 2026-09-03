import 'dart:convert';
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

class _FakeSource implements ProgressSyncSource {
  final Map<String, ReadingProgress> progress = {};
  final Set<String> books = {};

  @override
  Future<ReadingProgress?> getProgress(String bookUid) async =>
      progress[bookUid];

  @override
  Future<List<ReadingProgress>> listAllProgress() async =>
      progress.values.toList();

  @override
  Future<void> saveProgress(ReadingProgress value) async {
    progress[value.bookUid] = value;
  }

  @override
  Future<bool> hasBook(String bookUid) async => books.contains(bookUid);
}

ReadingProgress _progress(
  String uid,
  int updatedAt,
  double progression, {
  String? href,
}) {
  return ReadingProgress(
    bookUid: uid,
    locator: Locator(
      href: href ?? 'chap.xhtml',
      locations: {'position': progression},
    ),
    progression: progression,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    lastReadAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
  );
}

SyncConfig _config({
  required String url,
  int? cursor,
  Map<String, String> hashes = const <String, String>{},
}) {
  return SyncConfig(
    serverUrl: url,
    token: 't',
    deviceId: 'dev1',
    cursor: cursor,
    syncedContentHashes: hashes,
  );
}

void main() {
  test('内容和位置未变化时不会推送,时间变化也不会触发推送', () async {
    final source = _FakeSource()
      ..books.add('b1')
      ..progress['b1'] = _progress('b1', 100, 0.4);
    final server = await _FakeServer.start();
    addTearDown(server.close);
    final originalHash = readingProgressContentHash(source.progress['b1']!);
    final store = _FakeConfigStore(
      _config(url: server.url, cursor: 1, hashes: {'b1': originalHash}),
    );
    final service = ProgressSyncService(
      api: SyncApiClient(),
      source: source,
      configStore: store,
    );

    final result = await service.pushBookOnExit('b1');

    expect(result.pushed, 0);
    expect(server.pushRequests, 0);
  });

  test('syncAll只推送内容指纹变化的书籍', () async {
    final source = _FakeSource()
      ..books.addAll({'b1', 'b2'})
      ..progress['b1'] = _progress('b1', 100, 0.4)
      ..progress['b2'] = _progress('b2', 100, 0.8);
    final server = await _FakeServer.start();
    addTearDown(server.close);
    final b1Hash = readingProgressContentHash(source.progress['b1']!);
    final store = _FakeConfigStore(
      _config(
        url: server.url,
        cursor: 1,
        hashes: {'b1': b1Hash, 'b2': 'old-hash'},
      ),
    );
    final service = ProgressSyncService(
      api: SyncApiClient(),
      source: source,
      configStore: store,
    );

    final result = await service.syncAll();

    expect(result.pushed, 1);
    expect(server.pushRequests, 1);
    expect(server.lastPushItemCount, 1);
  });

  test('游标拉取不受设备时间偏差影响', () async {
    final source = _FakeSource()..books.addAll({'b1', 'b2'});
    source.progress['b1'] = _progress('b1', 9000000000000, 0.1);
    final server = await _FakeServer.start(
      pullResponses: [
        {
          'items': [_progressJson(_progress('b2', 1, 0.9))],
          'cursor': 2,
          'serverTime': 500,
        },
      ],
    );
    addTearDown(server.close);
    final b1Hash = readingProgressContentHash(source.progress['b1']!);
    final store = _FakeConfigStore(
      _config(url: server.url, cursor: 1, hashes: {'b1': b1Hash}),
    );
    final service = ProgressSyncService(
      api: SyncApiClient(),
      source: source,
      configStore: store,
    );

    final result = await service.syncAll();

    expect(result.pulled, 1);
    expect(source.progress['b2']!.progression, 0.9);
    expect(store.load().cursor, 2);
  });

  test('首次迁移保留服务器记录,只推送本地独有内容', () async {
    final source = _FakeSource()
      ..books.addAll({'remote', 'local'})
      ..progress['local'] = _progress('local', 100, 0.2);
    final server = await _FakeServer.start(
      pullResponses: [
        {
          'items': [_progressJson(_progress('remote', 200, 0.7))],
          'cursor': 5,
          'serverTime': 500,
        },
        {
          'items': [_progressJson(_progress('local', 100, 0.2))],
          'cursor': 6,
          'serverTime': 600,
        },
      ],
    );
    addTearDown(server.close);
    final store = _FakeConfigStore(_config(url: server.url));
    final service = ProgressSyncService(
      api: SyncApiClient(),
      source: source,
      configStore: store,
    );

    final result = await service.syncAll();

    expect(result.pushed, 1);
    expect(result.pulled, 1);
    expect(server.lastPushItemCount, 1);
    expect(source.progress['remote']!.progression, 0.7);
    expect(store.load().cursor, 6);
  });
}

Map<String, dynamic> _progressJson(ReadingProgress progress) {
  return {
    'bookUid': progress.bookUid,
    'locator': jsonEncode(progress.locator.toJson()),
    'progression': progress.progression,
    'updatedAt': progress.updatedAt.millisecondsSinceEpoch,
    'lastReadAt': progress.lastReadAt?.millisecondsSinceEpoch,
  };
}

class _FakeServer {
  _FakeServer(this._server, this._pullResponses);

  final HttpServer _server;
  final List<Map<String, dynamic>> _pullResponses;
  int pushRequests = 0;
  int lastPushItemCount = 0;

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_FakeServer> start({
    List<Map<String, dynamic>> pullResponses = const <Map<String, dynamic>>[],
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeServer(server, [...pullResponses]);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/api/sync/push') {
      final body = jsonDecode(
        await request.cast<List<int>>().transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;
      pushRequests++;
      lastPushItemCount = (body['items'] as List).length;
      _write(request.response,
          {'accepted': lastPushItemCount, 'changed': lastPushItemCount});
      return;
    }
    if (request.uri.path == '/api/sync/pull') {
      final response = _pullResponses.isEmpty
          ? <String, dynamic>{
              'items': <dynamic>[],
              'cursor': 1,
              'serverTime': 500
            }
          : _pullResponses.removeAt(0);
      _write(request.response, response);
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  void _write(HttpResponse response, Map<String, dynamic> body) {
    response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }

  Future<void> close() => _server.close(force: true);
}
