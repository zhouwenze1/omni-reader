import 'dart:convert';
import 'dart:io';

import 'package:foundation_domain/domain.dart';

/// Progress push API 返回的数据模型。
class SyncPushResult {
  const SyncPushResult({required this.accepted, required this.changed});

  final int accepted;
  final int changed;
}

/// Progress pull API 返回的数据模型。
class SyncPullResult {
  const SyncPullResult({
    required this.items,
    required this.serverTime,
    required this.cursor,
  });

  final List<ReadingProgress> items;
  final DateTime serverTime;
  final int? cursor;
}

/// 同步 API 客户端,用 dart:io HttpClient 与自建 Go 服务器通信。
class SyncApiClient {
  SyncApiClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  /// 批量推送进度。
  Future<SyncPushResult> push({
    required String serverUrl,
    required String token,
    required String deviceId,
    required List<ReadingProgress> items,
  }) async {
    final url = _endpoint(serverUrl, '/api/sync/push');
    final body = jsonEncode({
      'deviceId': deviceId,
      'items': items.map((p) => _progressToJson(p)).toList(),
    });
    final request = await _http.postUrl(url);
    _auth(request, token);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(body));
    final response = await request.close();
    final json = await _parseResponse(response);
    if (response.statusCode != 200) {
      throw SyncApiException(response.statusCode, json['error'] as String?);
    }
    final accepted = (json['accepted'] as num?)?.toInt() ?? 0;
    final changed = (json['changed'] as num?)?.toInt() ?? accepted;
    return SyncPushResult(accepted: accepted, changed: changed);
  }

  /// 拉取增量。
  Future<SyncPullResult> pull({
    required String serverUrl,
    required String token,
    required String deviceId,
    DateTime? after,
    int? cursor,
    String? bookUid,
  }) async {
    final params = <String, String>{'deviceId': deviceId};
    if (bookUid != null) {
      params['bookUid'] = bookUid;
    } else if (cursor != null) {
      params['cursor'] = '$cursor';
    } else if (after != null) {
      params['after'] = after.toUtc().toIso8601String();
    }
    final url =
        _endpoint(serverUrl, '/api/sync/pull').replace(queryParameters: params);
    final request = await _http.getUrl(url);
    _auth(request, token);
    final response = await request.close();
    final json = await _parseResponse(response);
    if (response.statusCode != 200) {
      throw SyncApiException(response.statusCode, json['error'] as String?);
    }
    return parsePullJson(json);
  }

  /// 解析 pull 响应。服务端无记录时 items 为 JSON null(Go nil 切片),必须容错。
  static SyncPullResult parsePullJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final items = <ReadingProgress>[
      for (final item in rawItems ?? const <dynamic>[])
        _progressFromJson(item as Map<String, dynamic>),
    ];
    final serverTime = DateTime.fromMillisecondsSinceEpoch(
      (json['serverTime'] as num).toInt(),
      isUtc: true,
    );
    final cursorRaw = json['cursor'];
    final responseCursor = cursorRaw is num ? cursorRaw.toInt() : null;
    return SyncPullResult(
      items: items,
      serverTime: serverTime,
      cursor: responseCursor,
    );
  }

  /// v2 实体(标注/设置/统计)推送。payload 为该实体的 JSON 体,服务端不透明存储。
  Future<SyncPushResult> pushEntity({
    required String serverUrl,
    required String token,
    required String deviceId,
    required String entity,
    required List<Map<String, dynamic>> items,
  }) async {
    final url = _endpoint(serverUrl, '/api/v2/sync/$entity/push');
    final body = jsonEncode({'deviceId': deviceId, 'items': items});
    final request = await _http.postUrl(url);
    _auth(request, token);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(body));
    final response = await request.close();
    final json = await _parseResponse(response);
    if (response.statusCode != 200) {
      throw SyncApiException(response.statusCode, json['error'] as String?);
    }
    final accepted = (json['accepted'] as num?)?.toInt() ?? 0;
    final changed = (json['changed'] as num?)?.toInt() ?? accepted;
    return SyncPushResult(accepted: accepted, changed: changed);
  }

  /// v2 实体增量拉取。cursor 从 0 开始回放全量。
  Future<EntityPullResult> pullEntity({
    required String serverUrl,
    required String token,
    required String entity,
    required int cursor,
  }) async {
    final url = _endpoint(serverUrl, '/api/v2/sync/$entity/pull')
        .replace(queryParameters: {'cursor': '$cursor'});
    final request = await _http.getUrl(url);
    _auth(request, token);
    final response = await request.close();
    final json = await _parseResponse(response);
    if (response.statusCode != 200) {
      throw SyncApiException(response.statusCode, json['error'] as String?);
    }
    final serverTime = DateTime.fromMillisecondsSinceEpoch(
      (json['serverTime'] as num).toInt(),
      isUtc: true,
    );
    final rawItems = json['items'] as List<dynamic>?;
    final items = <EntitySyncItem>[
      for (final item in rawItems ?? const <dynamic>[])
        EntitySyncItem.fromJson(item as Map<String, dynamic>),
    ];
    final responseCursor = (json['cursor'] as num?)?.toInt() ?? cursor;
    return EntityPullResult(
      items: items,
      serverTime: serverTime,
      cursor: responseCursor,
    );
  }

  void _auth(HttpClientRequest request, String token) {
    request.headers.set('Authorization', 'Bearer $token');
  }

  Uri _endpoint(String serverUrl, String path) {
    final base = serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>> _parseResponse(
      HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    if (body.isEmpty) return <String, dynamic>{};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _progressToJson(ReadingProgress p) {
    return {
      'bookUid': p.bookUid,
      'locator': jsonEncode(p.locator.toJson()),
      'progression': p.progression,
      'updatedAt': p.updatedAt.millisecondsSinceEpoch,
      'lastReadAt': p.lastReadAt?.millisecondsSinceEpoch,
    };
  }

  static ReadingProgress _progressFromJson(Map<String, dynamic> json) {
    final rawLocator = json['locator'];
    if (rawLocator is String) {
      return ReadingProgress.fromJson({
        ...json,
        'locator': jsonDecode(rawLocator),
      });
    }
    return ReadingProgress.fromJson(json);
  }
}

/// v2 实体拉取结果。
class EntityPullResult {
  const EntityPullResult({
    required this.items,
    required this.serverTime,
    required this.cursor,
  });

  final List<EntitySyncItem> items;
  final DateTime serverTime;
  final int cursor;
}

/// v2 实体条目(payload 为该实体的原始 JSON 体)。
class EntitySyncItem {
  const EntitySyncItem({
    required this.key,
    required this.payload,
    required this.updatedAt,
    required this.deleted,
  });

  final String key;
  final Map<String, dynamic> payload;
  final int updatedAt;
  final bool deleted;

  factory EntitySyncItem.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return EntitySyncItem(
      key: '${json['key'] ?? ''}',
      payload: payload is Map<String, dynamic>
          ? payload
          : payload is Map
              ? payload.map((k, v) => MapEntry('$k', v))
              : const <String, dynamic>{},
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      deleted: json['deleted'] == true,
    );
  }
}

class SyncApiException implements Exception {
  SyncApiException(this.statusCode, this.message);
  final int statusCode;
  final String? message;
  @override
  String toString() => 'SyncApiException($statusCode): $message';
}
