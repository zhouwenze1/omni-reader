import 'dart:convert';
import 'dart:io';

import 'library_api_client.dart';
import 'sync_ports.dart';

/// 书原始文件后端:书库备份的大文件(EPUB 原件)存哪。
///
/// 书单/封面/进度/标注始终走自建服务器;只有这个大文件存储可插拔——
/// 自建服务器 vault(默认)或用户自有 WebDAV(坚果云等)。
abstract class BookFilesBackend {
  Future<void> uploadOriginal(String bookUid, File file, String ext);

  Future<void> downloadOriginal(
    String bookUid,
    File saveTo, {
    void Function(int received, int? total)? onProgress,
  });

  Future<void> deleteOriginal(String bookUid);
}

/// 自建服务器 vault 后端(与书单同一服务器、同一 token)。
class ServerFilesBackend implements BookFilesBackend {
  ServerFilesBackend(this._api, this._config);

  final LibraryApiClient _api;
  final SyncConfig Function() _config;

  @override
  Future<void> uploadOriginal(String bookUid, File file, String ext) {
    final config = _config();
    return _api.uploadBookFile(
      serverUrl: config.serverUrl,
      token: config.token,
      bookUid: bookUid,
      ext: ext,
      file: file,
    );
  }

  @override
  Future<void> downloadOriginal(
    String bookUid,
    File saveTo, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final config = _config();
    await _api.downloadBookFile(
      serverUrl: config.serverUrl,
      token: config.token,
      bookUid: bookUid,
      saveTo: saveTo,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> deleteOriginal(String bookUid) async {
    final config = _config();
    await _api.deleteCloudBook(
      serverUrl: config.serverUrl,
      token: config.token,
      bookUid: bookUid,
    );
  }
}

/// 按当前配置解析文件后端:启用了 WebDAV 则走 WebDAV,否则走服务器 vault。
BookFilesBackend resolveFilesBackend(SyncConfig config, LibraryApiClient api) {
  if (config.webdavConfigured) {
    return WebDavFilesBackend(
      baseUrl: config.webdavUrl,
      username: config.webdavUsername,
      password: config.webdavPassword,
    );
  }
  return ServerFilesBackend(api, () => config);
}

/// WebDAV 后端:最小集 MKCOL/PUT/GET/DELETE,Basic 认证(坚果云兼容)。
class WebDavFilesBackend implements BookFilesBackend {
  WebDavFilesBackend({
    required String baseUrl,
    required String username,
    required String password,
    HttpClient? httpClient,
  })  : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
        _username = username,
        _password = password,
        _http = httpClient ?? HttpClient();

  static const String _root = 'omni-books';

  final String _baseUrl;
  final String _username;
  final String _password;
  final HttpClient _http;

  @override
  Future<void> uploadOriginal(String bookUid, File file, String ext) async {
    final url = _fileUrl(bookUid, ext);
    await _ensureCollection(_collectionUrl(bookUid));
    final request = await _http.putUrl(url);
    _auth(request);
    request.headers.contentType = ContentType.binary;
    await request.addStream(file.openRead());
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
      throw WebDavException('WebDAV PUT failed: HTTP ${response.statusCode}');
    }
  }

  @override
  Future<void> downloadOriginal(
    String bookUid,
    File saveTo, {
    void Function(int received, int? total)? onProgress,
  }) async {
    // 扩展名未知时逐个尝试(epub 是当前唯一书格式)。
    Object? lastError;
    for (final ext in const ['epub']) {
      final request = await _http.getUrl(_fileUrl(bookUid, ext));
      _auth(request);
      final response = await request.close();
      if (response.statusCode == 404) {
        await response.drain<void>();
        lastError = WebDavException('WebDAV file not found');
        continue;
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw WebDavException('WebDAV GET failed: HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0 ? response.contentLength : null;
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
      return;
    }
    throw lastError ?? WebDavException('WebDAV file not found');
  }

  @override
  Future<void> deleteOriginal(String bookUid) async {
    final request = await _http.deleteUrl(_collectionUrl(bookUid));
    _auth(request);
    final response = await request.close();
    await response.drain<void>();
    // 404 视为已删除,不报错。
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw WebDavException('WebDAV DELETE failed: HTTP ${response.statusCode}');
    }
  }

  /// WebDAV 连通性检查(设置页"测试连接"):确保根集合存在。
  Future<void> testConnection() async {
    await _mkcolIfMissing(Uri.parse('$_baseUrl/$_root'));
  }

  Uri _collectionUrl(String bookUid) =>
      Uri.parse('$_baseUrl/$_root/$bookUid/');

  Uri _fileUrl(String bookUid, String ext) =>
      Uri.parse('$_baseUrl/$_root/$bookUid/original.$ext');

  Future<void> _ensureCollection(Uri collectionUrl) async {
    await _mkcolIfMissing(Uri.parse('$_baseUrl/$_root'));
    await _mkcolIfMissing(collectionUrl);
  }

  Future<void> _mkcolIfMissing(Uri url) async {
    final request = await _http.openUrl('MKCOL', url);
    _auth(request);
    final response = await request.close();
    await response.drain<void>();
    // 201 创建成功;405/409 已存在(坚果云对已存在集合返回 409)。
    if (response.statusCode == 201 ||
        response.statusCode == 405 ||
        response.statusCode == 409 ||
        response.statusCode == 200) {
      return;
    }
    throw WebDavException('WebDAV MKCOL failed: HTTP ${response.statusCode}');
  }

  void _auth(HttpClientRequest request) {
    final credentials = base64Encode(utf8.encode('$_username:$_password'));
    request.headers.set('Authorization', 'Basic $credentials');
  }
}

class WebDavException implements Exception {
  WebDavException(this.message);

  final String message;

  @override
  String toString() => message;
}
