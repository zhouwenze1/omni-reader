import 'dart:async';
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

class _FakeProgress implements ProgressSyncSource {
  final Set<String> books = {'book-a'};

  @override
  Future<ReadingProgress?> getProgress(String bookUid) async => null;

  @override
  Future<List<ReadingProgress>> listAllProgress() async => [];

  @override
  Future<void> saveProgress(ReadingProgress progress) async {}

  @override
  Future<bool> hasBook(String bookUid) async => books.contains(bookUid);
}

class _FakeAnnotations implements AnnotationSyncSource {
  final Map<String, List<Annotation>> byBook = {};
  final List<AnnotationTombstone> tombstones = [];

  @override
  Future<List<Annotation>> listAnnotations(String bookUid) async =>
      byBook[bookUid] ?? const [];

  @override
  Future<void> replaceAnnotations(
    String bookUid,
    List<Annotation> annotations,
  ) async {
    byBook[bookUid] = annotations;
  }

  @override
  Future<List<AnnotationTombstone>> pendingAnnotationTombstones() async =>
      tombstones;

  @override
  Future<void> confirmTombstones(List<String> ids) async {
    tombstones.removeWhere((t) => ids.contains(t.id));
  }
}

class _FakeSettings implements SettingsSyncSource {
  ReaderSettings settings = const ReaderSettings();
  int applied = 0;

  @override
  Future<ReaderSettings> getReaderSettings() async => settings;

  @override
  Future<void> saveReaderSettings(ReaderSettings value) async {
    settings = value;
    applied++;
  }
}

class _FakeStats implements StatsSyncSource {
  final List<ReadingSessionRecord> local = [];
  List<ReadingSessionRecord> since = [];

  @override
  Future<List<ReadingSessionRecord>> sessionsSince(int sinceMs) async => since;

  @override
  Future<bool> hasSession({
    required String deviceId,
    required int startedAtMs,
  }) async {
    return local.any((r) =>
        r.deviceId == deviceId && r.startedAtMs == startedAtMs);
  }

  @override
  Future<void> insertSyncedSession(ReadingSessionRecord record) async {
    local.add(record);
  }
}

/// 本地 fake:v2 push 记录条目,pull 按 entity 出队响应。
class _EntityFakeServer {
  _EntityFakeServer(this._server);

  final HttpServer _server;
  final Map<String, List<Map<String, dynamic>>> pullResponses = {};
  final List<Map<String, dynamic>> pushedItems = [];
  int changedToReturn = 1;

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_EntityFakeServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _EntityFakeServer(server);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest request) async {
    final match =
        RegExp(r'/api/v2/sync/(annotation|setting|stat)/(push|pull)$')
            .firstMatch(request.uri.path);
    if (match == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final entity = match.group(1)!;
    final op = match.group(2)!;
    if (op == 'push') {
      final body = jsonDecode(
        await request.cast<List<int>>().transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;
      final items = (body['items'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      pushedItems.addAll(items);
      _write(request.response, {
        'accepted': items.length,
        'changed': items.isEmpty ? 0 : changedToReturn,
      });
      return;
    }
    final responses = pullResponses[entity];
    _write(request.response, responses == null || responses.isEmpty
        ? {'items': [], 'cursor': 0, 'serverTime': 500}
        : responses.removeAt(0));
  }

  void _write(HttpResponse response, Map<String, dynamic> body) {
    response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }

  Future<void> close() => _server.close(force: true);
}

Annotation _annotation(
  String id,
  String bookUid,
  int updatedAt, {
  String? note,
}) {
  return Annotation(
    id: id,
    bookUid: bookUid,
    type: note == null ? AnnotationType.highlight : AnnotationType.note,
    locator: Locator(href: 'c1.xhtml', locations: {'position': 0.5}),
    note: note,
    createdAt: DateTime.fromMillisecondsSinceEpoch(100),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
  );
}

void main() {
  late _EntityFakeServer server;
  late _FakeConfigStore configStore;
  late _FakeAnnotations annotations;
  late _FakeSettings settings;
  late _FakeStats stats;
  late DataSyncService service;

  setUp(() async {
    server = await _EntityFakeServer.start();
    configStore = _FakeConfigStore(SyncConfig(
      serverUrl: server.url,
      token: 't',
      deviceId: 'dev1',
      autoSync: true,
    ));
    annotations = _FakeAnnotations();
    settings = _FakeSettings();
    stats = _FakeStats();
    service = DataSyncService(
      api: SyncApiClient(),
      configStore: configStore,
      progress: _FakeProgress(),
      annotations: annotations,
      settings: settings,
      stats: stats,
    );
  });

  tearDown(() async {
    await server.close();
  });

  test('annotation pull merges by updatedAt and applies tombstones',
      () async {
    annotations.byBook['book-a'] = [
      _annotation('a1', 'book-a', 1000, note: '旧笔记'),
      _annotation('a2', 'book-a', 1000),
    ];
    server.pullResponses['annotation'] = [
      {
        'items': [
          {
            'key': 'a1',
            'payload': _annotation('a1', 'book-a', 2000, note: '新笔记').toJson(),
            'updatedAt': 2000,
          },
          {'key': 'a2', 'payload': {'bookUid': 'book-a'}, 'updatedAt': 3000, 'deleted': true},
        ],
        'cursor': 7,
        'serverTime': 3000,
      },
    ];

    final result = await service.syncAll();
    expect(result.hasError, isFalse);
    final merged = annotations.byBook['book-a']!;
    expect(merged, hasLength(1));
    expect(merged.first.id, 'a1');
    expect(merged.first.note, '新笔记');
    expect(configStore.load().entityCursors['annotation'], 7);
  });

  test('settings pull applies remote when newer than local baseline',
      () async {
    server.pullResponses['setting'] = [
      {
        'items': [
          {
            'key': 'reader_style',
            'payload': const ReaderSettings(fontSize: 22).toJson(),
            'updatedAt': 900,
          },
        ],
        'cursor': 3,
        'serverTime': 1000,
      },
    ];

    final result = await service.syncAll();
    expect(result.hasError, isFalse);
    expect(settings.settings.fontSize, 22);
    expect(configStore.load().styleSyncedAt, 900);
    // 再拉一次同样的内容不再应用(时间不更新)。
    server.pullResponses['setting'] = [
      {
        'items': [
          {
            'key': 'reader_style',
            'payload': const ReaderSettings(fontSize: 22).toJson(),
            'updatedAt': 900,
          },
        ],
        'cursor': 3,
        'serverTime': 1000,
      },
    ];
    // styleSyncedHash 已记录,时间相同跳过。
    settings.settings = const ReaderSettings(fontSize: 18);
    await service.syncAll();
    expect(settings.settings.fontSize, 18);
  });

  test('stats push sends keyed sessions and pull inserts uniques only',
      () async {
    stats.since = [
      const ReadingSessionRecord(
        deviceId: 'dev1',
        bookUid: 'book-a',
        startedAtMs: 1000,
        endedAtMs: 2000,
        seconds: 60,
        day: '2026-09-06',
        startHour: 10,
      ),
    ];
    await service.pushOnReaderExit('book-a');
    expect(
      server.pushedItems
          .where((item) => item['key'] == 'dev1:1000')
          .length,
      1,
    );

    server.pullResponses['stat'] = [
      {
        'items': [
          {
            'key': 'dev2:5000',
            'payload': const ReadingSessionRecord(
              deviceId: 'dev2',
              bookUid: 'book-a',
              startedAtMs: 5000,
              endedAtMs: 6000,
              seconds: 120,
              day: '2026-09-06',
              startHour: 11,
            ).toJson(),
            'updatedAt': 5000,
          },
          {
            // 本机已有(自己推过的),拉取应跳过。
            'key': 'dev1:1000',
            'payload': const ReadingSessionRecord(
              deviceId: 'dev1',
              bookUid: 'book-a',
              startedAtMs: 1000,
              endedAtMs: 2000,
              seconds: 60,
              day: '2026-09-06',
              startHour: 10,
            ).toJson(),
            'updatedAt': 1000,
          },
        ],
        'cursor': 9,
        'serverTime': 6000,
      },
    ];
    final result = await service.syncAll();
    expect(result.hasError, isFalse);
    expect(stats.local, hasLength(2));
    expect(stats.local.any((r) => r.deviceId == 'dev2'), isTrue);
    expect(configStore.load().entityCursors['stat'], 9);
  });

  test('local annotation tombstones are pushed and confirmed', () async {
    annotations.tombstones.add(
      const AnnotationTombstone(
        id: 'a3',
        bookUid: 'book-a',
        updatedAt: 4000,
      ),
    );

    final result = await service.pushOnReaderExit('book-a');
    expect(result.hasError, isFalse);
    final tombstoneItem =
        server.pushedItems.firstWhere((item) => item['key'] == 'a3');
    expect(tombstoneItem['deleted'], isTrue);
    expect((tombstoneItem['payload'] as Map)['bookUid'], 'book-a');
    // 推送确认后墓碑清空,不再重复传播。
    expect(annotations.tombstones, isEmpty);
  });

  test('content switches gate each entity', () async {
    final config = configStore.load();
    await configStore.save(config.copyWith(
      syncAnnotations: false,
      syncSettings: false,
      syncStats: false,
    ));
    stats.since = [
      const ReadingSessionRecord(
        deviceId: 'dev1',
        bookUid: 'book-a',
        startedAtMs: 1000,
        endedAtMs: 2000,
        seconds: 60,
        day: '2026-09-06',
        startHour: 10,
      ),
    ];
    await service.syncAll();
    expect(server.pushedItems, isEmpty);
  });
}
