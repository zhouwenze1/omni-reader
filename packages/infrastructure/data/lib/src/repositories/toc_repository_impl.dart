import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import '../services/storage_paths.dart';

class TocRepositoryImpl implements TocRepository {
  TocRepositoryImpl({
    required StoragePaths storagePaths,
    required FileService fileService,
  }) : _storagePaths = storagePaths,
       _fileService = fileService;

  final StoragePaths _storagePaths;
  final FileService _fileService;

  @override
  Future<List<TocItem>> getToc(String bookUid) async {
    final manifest = await _fileService.readJson(
      _bookArtifactPath(bookUid, 'manifest.json'),
    );
    final manifestToc = _readManifestToc(bookUid, manifest);
    if (manifestToc.isNotEmpty) {
      return manifestToc;
    }

    final metadata = await _fileService.readJson(
      _bookArtifactPath(bookUid, 'meta.json'),
    );
    final metadataToc = _readMetadataToc(bookUid, metadata);
    if (metadataToc.isNotEmpty) {
      return metadataToc;
    }

    final legacy = await _fileService.readJson(_bookArtifactPath(bookUid, 'toc.json')) ??
        await _fileService.readJson(
          p.join(_storagePaths.libraryRoot.path, bookUid, 'toc.json'),
        );
    if (legacy == null) {
      return const [];
    }

    final list = (legacy['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((it) => TocItem.fromJson(it.map((k, v) => MapEntry('$k', v))))
        .toList();
    return list;
  }

  @override
  Future<void> saveToc(String bookUid, List<TocItem> toc) {
    final filePath = _bookArtifactPath(bookUid, 'toc.json');
    return _fileService.writeJsonAtomic(filePath, {
      'items': toc.map((item) => item.toJson()).toList(),
    });
  }

  String _bookArtifactPath(String bookUid, String fileName) {
    return p.join(_storagePaths.booksRoot.path, bookUid, fileName);
  }

  List<TocItem> _readManifestToc(
    String bookUid,
    Map<String, dynamic>? manifest,
  ) {
    if (manifest == null) {
      return const [];
    }
    final toc = manifest['toc'];
    if (toc is! List) {
      return const [];
    }

    final items = <TocItem>[];
    var order = 0;

    void walk(
      List<dynamic> nodes, {
      required int level,
      String? parentId,
      String pathPrefix = 'toc',
    }) {
      for (var index = 0; index < nodes.length; index += 1) {
        final rawNode = nodes[index];
        if (rawNode is! Map) {
          continue;
        }
        final node = rawNode.map((key, value) => MapEntry('$key', value));
        final title = '${node['title'] ?? ''}'.trim();
        final href = '${node['href'] ?? ''}'.trim();
        final id = '${node['id'] ?? ''}'.trim().isNotEmpty
            ? '${node['id']}'.trim()
            : '$pathPrefix.$index';
        items.add(
          TocItem(
            id: id,
            bookUid: bookUid,
            title: title.isEmpty ? _fallbackTitle(href, order) : title,
            href: href.isEmpty ? null : href,
            order: order,
            level: level,
            parentId: parentId,
          ),
        );
        order += 1;

        final children = node['children'];
        if (children is List && children.isNotEmpty) {
          walk(
            children,
            level: level + 1,
            parentId: id,
            pathPrefix: id,
          );
        }
      }
    }

    walk(toc, level: 0);
    return items;
  }

  List<TocItem> _readMetadataToc(
    String bookUid,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) {
      return const [];
    }
    final toc = metadata['toc'];
    if (toc is! List) {
      return const [];
    }

    return toc
        .whereType<Map>()
        .map(
          (item) => TocItem.fromJson(
            <String, dynamic>{
              'bookUid': bookUid,
              ...item.map((key, value) => MapEntry('$key', value)),
            },
          ),
        )
        .toList(growable: false);
  }

  String _fallbackTitle(String href, int order) {
    if (href.isEmpty) {
      return 'Chapter ${order + 1}';
    }
    final fileName = p.basenameWithoutExtension(href).trim();
    if (fileName.isEmpty) {
      return 'Chapter ${order + 1}';
    }
    return fileName;
  }
}
