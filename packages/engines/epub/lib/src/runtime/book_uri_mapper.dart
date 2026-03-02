import 'package:path/path.dart' as p;

class BookUriMapper {
  BookUriMapper({
    required this.host,
    required this.port,
    required this.bookUuid,
    required this.contentRoot,
  });

  static const Set<String> _reservedTopLevel = <String>{
    'render',
    'assets',
    'health',
    'favicon.ico',
    'book',
  };

  final String host;
  final int port;
  final String bookUuid;
  final String contentRoot;

  String get origin => 'http://$host:$port';

  String bookBaseUrl() {
    return '$origin/';
  }

  String hrefToHttp({required String href}) {
    final publicHref = toPublicHref(href);
    final parsed = Uri.parse(publicHref);
    final path = _normalizeRelative(parsed.path);
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      pathSegments: _splitPath(path),
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    ).toString();
  }

  String toPublicHref(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      return _stripContentRoot(_normalizeRelative(value));
    }

    if (parsed.scheme == 'http' || parsed.scheme == 'https') {
      return hrefFromHttpUrl(value);
    }

    if (parsed.scheme == 'book') {
      final path = _normalizeRelative(parsed.path);
      final stripped = _stripContentRoot(path);
      return Uri(
        path: stripped,
        query: parsed.hasQuery ? parsed.query : null,
        fragment: parsed.hasFragment ? parsed.fragment : null,
      ).toString();
    }

    final path = _normalizeRelative(parsed.path.isEmpty ? value : parsed.path);
    final stripped = _stripContentRoot(path);
    return Uri(
      path: stripped,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    ).toString();
  }

  String bookToHttp(String bookUri) {
    final parsed = Uri.parse(bookUri);
    if (parsed.scheme != 'book') {
      return hrefToHttp(href: bookUri);
    }

    final path = _normalizeRelative(parsed.path);
    final stripped = _stripContentRoot(path);
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      pathSegments: _splitPath(stripped),
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    ).toString();
  }

  String? httpToBook(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    if (uri.host != host || uri.port != port) {
      return null;
    }

    final publicPath = _normalizeRelative(uri.path);
    if (publicPath.isNotEmpty && _isReserved(publicPath)) {
      return null;
    }

    final bookPath = _addContentRoot(publicPath);
    final mapped = Uri(
      scheme: 'book',
      host: bookUuid,
      path: '/$bookPath',
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    );
    return mapped.toString();
  }

  String hrefFromBookUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'book') {
      return toPublicHref(value);
    }
    final stripped = _stripContentRoot(_normalizeRelative(uri.path));
    return Uri(
      path: stripped,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }

  String hrefFromHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return toPublicHref(value);
    }
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host != host ||
        uri.port != port) {
      return toPublicHref(value);
    }
    final path = _normalizeRelative(uri.path);
    return Uri(
      path: path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }

  bool _isReserved(String publicPath) {
    final first = publicPath.split('/').first;
    return _reservedTopLevel.contains(first);
  }

  String _addContentRoot(String publicPath) {
    final cleanContentRoot = _normalizeRelative(contentRoot);
    final cleanPublicPath = _normalizeRelative(publicPath);

    if (cleanPublicPath.isEmpty) {
      return cleanContentRoot;
    }
    if (cleanContentRoot.isEmpty) {
      return cleanPublicPath;
    }
    if (cleanPublicPath == cleanContentRoot ||
        cleanPublicPath.startsWith('$cleanContentRoot/')) {
      return cleanPublicPath;
    }
    return p.posix.join(cleanContentRoot, cleanPublicPath);
  }

  String _stripContentRoot(String value) {
    final cleanContentRoot = _normalizeRelative(contentRoot);
    final normalized = _normalizeRelative(value);

    if (cleanContentRoot.isEmpty || normalized.isEmpty) {
      return normalized;
    }
    if (normalized == cleanContentRoot) {
      return '';
    }
    if (normalized.startsWith('$cleanContentRoot/')) {
      return normalized.substring(cleanContentRoot.length + 1);
    }
    return normalized;
  }

  List<String> _splitPath(String path) {
    if (path.isEmpty) {
      return const <String>[];
    }
    return path
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  String _normalizeRelative(String value) {
    final raw = value.trim().replaceAll('\\', '/');
    if (raw.isEmpty || raw == '/') {
      return '';
    }
    final normalized = p.posix.normalize(raw);
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }
}
