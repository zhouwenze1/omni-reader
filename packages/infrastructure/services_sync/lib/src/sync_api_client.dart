import 'dart:convert';
import 'dart:io';

import 'package:foundation_domain/domain.dart';

/// Progress sync API 返回的数据模型。
class SyncPullResult {
  const SyncPullResult({required this.items, required this.serverTime});

  final List<ReadingProgress> items;
  final DateTime serverTime;
}

/// 同步 API 客户端,用 dart:io HttpClient 与自建 Go 服务器通信。
class SyncApiClient {
  SyncApiClient({HttpClient? httpClient})
      : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  /// 批量推送进度。
  Future<int> push({
    required String serverUrl,
    required String token,
    required String deviceId,
    required List<ReadingProgress> items,
  }) async {
    final url = Uri.parse('$serverUrl/api/sync/push');
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
    return (json['accepted'] as num?)?.toInt() ?? 0;
  }

  /// 拉取增量。
  Future<SyncPullResult> pull({
    required String serverUrl,
    required String token,
    required String deviceId,
    DateTime? after,
    String? bookUid,
  }) async {
    final params = <String, String>{'deviceId': deviceId};
    if (bookUid != null) {
      params['bookUid'] = bookUid;
    } else if (after != null) {
      params['after'] = after.toUtc().toIso8601String();
    }
    final url = Uri.parse('$serverUrl/api/sync/pull').replace(queryParameters: params);
    final request = await _http.getUrl(url);
    _auth(request, token);
    final response = await request.close();
    final json = await _parseResponse(response);
    if (response.statusCode != 200) {
      throw SyncApiException(response.statusCode, json['error'] as String?);
    }
    final items = (json['items'] as List)
        .cast<Map<String, dynamic>>()
        .map((m) => ReadingProgress.fromJson(m))
        .toList();
    final serverTime = DateTime.fromMillisecondsSinceEpoch(
      (json['serverTime'] as num).toInt(),
    );
    return SyncPullResult(items: items, serverTime: serverTime);
  }

  void _auth(HttpClientRequest request, String token) {
    request.headers.set('Authorization', 'Bearer $token');
  }

  Future<Map<String, dynamic>> _parseResponse(HttpClientResponse response) async {
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
}

class SyncApiException implements Exception {
  SyncApiException(this.statusCode, this.message);
  final int statusCode;
  final String? message;
  @override
  String toString() => 'SyncApiException($statusCode): $message';
}