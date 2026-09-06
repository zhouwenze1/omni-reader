import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'sync_api_client.dart';

/// 云端书单条目(对应服务端 library_manifest)。
class CloudBookManifestEntry {
  const CloudBookManifestEntry({
    required this.bookUid,
    required this.fingerprint,
    required this.title,
    required this.authorsJson,
    required this.format,
    required this.sizeBytes,
    required this.coverExt,
    required this.importedAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory CloudBookManifestEntry.fromJson(Map<String, dynamic> json) {
    return CloudBookManifestEntry(
      bookUid: json['bookUid'] as String,
      fingerprint: json['fingerprint'] as String? ?? '',
      title: json['title'] as String? ?? '',
      authorsJson: json['authorsJson'] as String? ?? '[]',
      format: json['format'] as String? ?? 'epub',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      coverExt: json['coverExt'] as String? ?? '',
      importedAt: (json['importedAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      deletedAt: (json['deletedAt'] as num?)?.toInt(),
    );
  }

  final String bookUid;
  final String fingerprint;
  final String title;
  final String authorsJson;
  final String format;
  final int sizeBytes;
  final String coverExt;
  final int importedAt;
  final int updatedAt;

  /// 非空表示该书已在云端删除(墓碑)。
  final int? deletedAt;

  bool get isTombstone => deletedAt != null;

  List<String> get authors {
    final decoded = jsonDecode(authorsJson);
    return (decoded as List<dynamic>? ?? const []).map((it) => '$it').toList();
  }
}

/// 书库云备份 API 客户端(自建服务器,与进度同步同一 token)。
class LibraryApiClient {
  LibraryApiClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  HttpClient get rawClient => _http;

  /// 拉取书单;since 为上次同步位点(毫秒),0 全量。
  Future<(List<CloudBookManifestEntry>, int serverTime)> fetchManifest({
    required String serverUrl,
    required String token,
    int since = 0,
  }) async {
    final url = _endpoint(serverUrl, '/api/library/manifest')
        .replace(queryParameters: {'since': '$since'});
    final request = await _http.getUrl(url);
    _auth(request, token);
    final response = await request.close();
    final json = await _parseJson(response);
    _throwOnError(response, json);
    final books = (json['books'] as List<dynamic>? ?? const [])
        .map((it) => CloudBookManifestEntry.fromJson(it as Map<String, dynamic>))
        .toList();
    final serverTime = (json['serverTime'] as num?)?.toInt() ?? 0;
    return (books, serverTime);
  }

  /// 上报书目元数据(可选封面 base64)。
  Future<void> announce({
    required String serverUrl,
    required String token,
    required String bookUid,
    required String fingerprint,
    required String title,
    required List<String> authors,
    required String format,
    required int sizeBytes,
    required int importedAt,
    String? coverExt,
    Uint8List? coverBytes,
  }) async {
    final url = _endpoint(serverUrl, '/api/library/announce');
    final request = await _http.postUrl(url);
    _auth(request, token);
    request.headers.contentType = ContentType.json;
    request.add(
      utf8.encode(
        jsonEncode({
          'bookUid': bookUid,
          'fingerprint': fingerprint,
          'title': title,
          'authorsJson': jsonEncode(authors),
          'format': format,
          'sizeBytes': sizeBytes,
          'importedAt': importedAt,
          if (coverBytes != null && coverBytes.isNotEmpty) ...{
            'coverExt': coverExt ?? 'jpg',
            'coverBase64': base64Encode(coverBytes),
          },
        }),
      ),
    );
    final response = await request.close();
    final json = await _parseJson(response);
    _throwOnError(response, json);
  }

  /// 流式上传原始书文件。
  Future<void> uploadBookFile({
    required String serverUrl,
    required String token,
    required String bookUid,
    required String ext,
    required File file,
  }) async {
    final url = _endpoint(serverUrl, '/api/books/$bookUid/file')
        .replace(queryParameters: {'ext': ext});
    final request = await _http.openUrl('PUT', url);
    _auth(request, token);
    request.headers.contentType = ContentType.binary;
    request.contentLength = file.lengthSync();
    await request.addStream(file.openRead());
    final response = await request.close();
    final json = await _parseJson(response);
    _throwOnError(response, json);
  }

  /// 流式下载原始书文件到 [saveTo]。
  Future<int> downloadBookFile({
    required String serverUrl,
    required String token,
    required String bookUid,
    required File saveTo,
    void Function(int received, int? total)? onProgress,
  }) async {
    final url = _endpoint(serverUrl, '/api/books/$bookUid/file');
    final request = await _http.getUrl(url);
    _auth(request, token);
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw SyncApiException(response.statusCode, 'download book failed');
    }
    final total = response.contentLength <= 0 ? null : response.contentLength;
    final sink = saveTo.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return received;
  }

  /// 下载封面字节;无封面抛 SyncApiException(404)。
  Future<Uint8List> downloadCover({
    required String serverUrl,
    required String token,
    required String bookUid,
  }) async {
    final url = _endpoint(serverUrl, '/api/books/$bookUid/cover');
    final request = await _http.getUrl(url);
    _auth(request, token);
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw SyncApiException(response.statusCode, 'cover not found');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// 删除云端书目(墓碑+文件)。
  Future<void> deleteCloudBook({
    required String serverUrl,
    required String token,
    required String bookUid,
  }) async {
    final url = _endpoint(serverUrl, '/api/library/$bookUid');
    final request = await _http.openUrl('DELETE', url);
    _auth(request, token);
    final response = await request.close();
    final json = await _parseJson(response);
    _throwOnError(response, json);
  }

  Uri _endpoint(String serverUrl, String path) {
    final base = Uri.parse(serverUrl.trim());
    return base.resolve(path);
  }

  void _auth(HttpClientRequest request, String token) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  Future<Map<String, dynamic>> _parseJson(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  void _throwOnError(HttpClientResponse response, Map<String, dynamic> json) {
    if (response.statusCode != 200) {
      throw SyncApiException(
        response.statusCode,
        json['error'] as String?,
      );
    }
  }
}
