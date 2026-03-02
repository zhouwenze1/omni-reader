import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class LocalReaderHttpServer {
  LocalReaderHttpServer._();

  static final LocalReaderHttpServer instance = LocalReaderHttpServer._();

  HttpServer? _server;
  Directory? _rendererRoot;
  Directory? _booksRoot;
  _ActiveBookMount? _activeBookMount;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  String get origin => 'http://127.0.0.1:$port';

  String? get rendererDebugUrl =>
      _server == null ? null : '$origin/render/index.html';

  String? get mountedBookRootPath => _activeBookMount?.mountRoot.path;

  Future<void> ensureStarted({
    required String booksRootPath,
    required String activeBookUuid,
    required String activeContentRoot,
    int? preferredPort,
  }) async {
    final booksRoot = Directory(booksRootPath);
    if (!await booksRoot.exists()) {
      await booksRoot.create(recursive: true);
    }
    _booksRoot = booksRoot;

    final server = _server;
    if (server != null &&
        preferredPort != null &&
        preferredPort != server.port) {
      await stop();
    }

    if (_server == null) {
      _rendererRoot = await _resolveRendererRoot();
      final handler = Pipeline().addHandler(_handleRequest);
      final bindPort = preferredPort ?? 0;
      try {
        _server = await shelf_io.serve(
          handler,
          InternetAddress.loopbackIPv4,
          bindPort,
        );
      } on SocketException catch (error) {
        throw StateError(
          'Failed to start reader server on port $bindPort: $error',
        );
      }
    }

    _activeBookMount = await _resolveActiveBookMount(
      activeBookUuid: activeBookUuid,
      activeContentRoot: activeContentRoot,
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _activeBookMount = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<Response> _handleRequest(Request request) async {
    final segments = request.url.pathSegments;

    if (segments.length == 1 && segments.first == 'health') {
      final mount = _activeBookMount;
      return Response.ok(
        jsonEncode(
          <String, dynamic>{
            'ok': true,
            'port': port,
            'activeBookUuid': mount?.bookUuid,
            'activeContentRoot': mount?.contentRoot ?? '',
            'activeMountPath': mount?.mountRoot.path,
          },
        ),
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      );
    }

    if (segments.firstOrNull == 'render') {
      final subPath =
          segments.length == 1 ? 'index.html' : segments.sublist(1).join('/');
      return _serveRendererFile(subPath);
    }

    if (segments.firstOrNull == 'assets') {
      final subPath = p.posix.joinAll(<String>['assets', ...segments.skip(1)]);
      return _serveRendererFile(subPath);
    }

    if (segments.length == 1 && segments.first == 'favicon.ico') {
      return _serveRendererFile('favicon.ico');
    }

    if (segments.isEmpty) {
      return _serveRendererFile('index.html');
    }

    if (segments.first == 'book' && segments.length >= 2) {
      final uuid = segments[1];
      final subPath = segments.length > 2 ? segments.sublist(2).join('/') : '';
      return _serveBookFile(uuid: uuid, subPath: subPath);
    }

    return _serveActiveBookFile(subPath: request.url.path);
  }

  Future<Response> _serveRendererFile(String subPath) async {
    final root = _rendererRoot;
    if (root == null) {
      return Response.internalServerError(body: 'Renderer root unavailable');
    }
    final resolvedPath = _safeJoin(root.path, subPath);
    if (resolvedPath == null) {
      return Response.forbidden('Invalid renderer path');
    }
    final file = File(resolvedPath);
    if (!await file.exists()) {
      return Response.notFound('Renderer file not found: $subPath');
    }
    return _serveFile(file);
  }

  Future<Response> _serveActiveBookFile({required String subPath}) async {
    final mount = _activeBookMount;
    if (mount == null) {
      return Response.notFound('No active mounted book');
    }

    final filePath = _safeJoin(mount.mountRoot.path, subPath);
    if (filePath == null) {
      return Response.forbidden('Invalid active book resource path');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return Response.notFound('Book resource not found');
    }
    return _serveFile(file);
  }

  Future<Response> _serveBookFile({
    required String uuid,
    required String subPath,
  }) async {
    final booksRoot = _booksRoot;
    if (booksRoot == null) {
      return Response.internalServerError(body: 'Books root unavailable');
    }

    final rawRoot = p.join(booksRoot.path, uuid, 'raw');
    final filePath = _safeJoin(rawRoot, subPath);
    if (filePath == null) {
      return Response.forbidden('Invalid book path');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return Response.notFound('Book resource not found');
    }
    return _serveFile(file);
  }

  Future<Response> _serveFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    final mimeType = _contentTypeForExt(ext) ?? lookupMimeType(file.path);
    final bytes = await file.readAsBytes();

    final headers = <String, String>{
      HttpHeaders.cacheControlHeader: 'no-cache',
    };
    if (mimeType != null && mimeType.isNotEmpty) {
      headers[HttpHeaders.contentTypeHeader] = mimeType;
    }

    return Response.ok(bytes, headers: headers);
  }

  String? _contentTypeForExt(String ext) {
    switch (ext) {
      case '.html':
        return 'text/html; charset=utf-8';
      case '.xhtml':
        return 'application/xhtml+xml; charset=utf-8';
      case '.xml':
      case '.opf':
      case '.ncx':
        return 'application/xml; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.js':
      case '.mjs':
        return 'application/javascript; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.svg':
        return 'image/svg+xml';
      case '.ttf':
        return 'font/ttf';
      case '.otf':
        return 'font/otf';
      case '.woff':
        return 'font/woff';
      case '.woff2':
        return 'font/woff2';
      default:
        return null;
    }
  }

  String? _safeJoin(String root, String subPath) {
    final normalizedRoot = p.normalize(root);
    final normalizedSub = p.posix.normalize(subPath.replaceAll('\\', '/'));
    final cleanSub = normalizedSub == '.'
        ? ''
        : normalizedSub.replaceFirst(RegExp(r'^/+'), '');
    final candidate = p.normalize(
      p.joinAll(
        <String>[
          normalizedRoot,
          ...cleanSub.split('/').where((segment) => segment.isNotEmpty),
        ],
      ),
    );
    if (candidate == normalizedRoot || p.isWithin(normalizedRoot, candidate)) {
      return candidate;
    }
    return null;
  }

  Future<_ActiveBookMount> _resolveActiveBookMount({
    required String activeBookUuid,
    required String activeContentRoot,
  }) async {
    final booksRoot = _booksRoot;
    if (booksRoot == null) {
      throw StateError('Books root unavailable');
    }

    final rawRoot = Directory(p.join(booksRoot.path, activeBookUuid, 'raw'));
    if (!await rawRoot.exists()) {
      throw StateError('Book raw directory not found: ${rawRoot.path}');
    }

    final cleanContentRoot = _normalizeRelative(activeContentRoot);
    final mountPath = cleanContentRoot.isEmpty
        ? rawRoot.path
        : p.joinAll(<String>[rawRoot.path, ...cleanContentRoot.split('/')]);

    final mountRoot = Directory(p.normalize(mountPath));
    if (!p.isWithin(rawRoot.path, mountRoot.path) &&
        rawRoot.path != mountRoot.path) {
      throw StateError(
          'Invalid contentRoot outside raw dir: $activeContentRoot');
    }
    if (!await mountRoot.exists()) {
      throw StateError(
        'Book content root not found: ${mountRoot.path} '
        '(contentRoot="$activeContentRoot")',
      );
    }

    return _ActiveBookMount(
      bookUuid: activeBookUuid,
      contentRoot: cleanContentRoot,
      mountRoot: mountRoot,
      rawRoot: rawRoot,
    );
  }

  String _normalizeRelative(String value) {
    final raw = value.trim().replaceAll('\\', '/');
    if (raw.isEmpty || raw == '.') {
      return '';
    }
    final normalized = p.posix.normalize(raw);
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  Future<Directory> _resolveRendererRoot() async {
    final fromWorkspace = await _tryWorkspaceRendererDir();
    if (fromWorkspace != null) {
      return fromWorkspace;
    }
    return _extractRendererAssetsToCache();
  }

  Future<Directory?> _tryWorkspaceRendererDir() async {
    final candidates = <String>[
      p.join(
        Directory.current.path,
        'packages',
        'engines',
        'epub',
        'assets',
        'renderer',
      ),
      p.join(
        Directory.current.path,
        '..',
        '..',
        'packages',
        'engines',
        'epub',
        'assets',
        'renderer',
      ),
      p.join(
        Directory.current.path,
        '..',
        'packages',
        'engines',
        'epub',
        'assets',
        'renderer',
      ),
    ];

    for (final candidate in candidates) {
      final dir = Directory(p.normalize(candidate));
      final indexFile = File(p.join(dir.path, 'index.html'));
      if (await indexFile.exists()) {
        return dir;
      }
    }
    return null;
  }

  Future<Directory> _extractRendererAssetsToCache() async {
    final tempDir = await getTemporaryDirectory();
    final target = Directory(p.join(tempDir.path, 'reader_renderer_assets'));
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);

    final keys = await _loadAssetManifestKeys();

    const prefix = 'packages/engine_epub/assets/renderer/';
    final rendererAssetKeys =
        keys.where((key) => key.startsWith(prefix)).toList()..sort();

    for (final assetKey in rendererAssetKeys) {
      final relative = assetKey.substring(prefix.length);
      if (relative.isEmpty) {
        continue;
      }
      final data = await rootBundle.load(assetKey);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final outputFile = File(
        p.joinAll(
          <String>[
            target.path,
            ...relative.split('/').where((segment) => segment.isNotEmpty),
          ],
        ),
      );
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(bytes, flush: true);
    }

    final indexFile = File(p.join(target.path, 'index.html'));
    if (!await indexFile.exists()) {
      throw StateError(
        'Renderer index.html not found in bundled assets under $prefix',
      );
    }
    return target;
  }

  Future<List<String>> _loadAssetManifestKeys() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final keys = manifest.listAssets().toList()..sort();
      if (keys.isNotEmpty) {
        return keys;
      }
    } catch (_) {}

    try {
      final manifestText = await rootBundle.loadString('AssetManifest.json');
      final manifestJson = jsonDecode(manifestText);
      final keys = <String>[];
      if (manifestJson is Map<String, dynamic>) {
        keys.addAll(manifestJson.keys);
      } else if (manifestJson is Map) {
        keys.addAll(manifestJson.keys.map((key) => '$key'));
      }
      keys.sort();
      return keys;
    } catch (_) {}

    throw StateError(
      'Unable to read asset manifest from AssetManifest API or AssetManifest.json',
    );
  }
}

class _ActiveBookMount {
  const _ActiveBookMount({
    required this.bookUuid,
    required this.contentRoot,
    required this.mountRoot,
    required this.rawRoot,
  });

  final String bookUuid;
  final String contentRoot;
  final Directory mountRoot;
  final Directory rawRoot;
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
