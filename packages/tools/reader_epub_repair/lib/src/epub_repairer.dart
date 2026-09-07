import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'epub_repair_models.dart';
import 'xhtml_serializer.dart';

class EpubRepairer {
  const EpubRepairer();

  Future<EpubInspection> inspect(String inputPath) async {
    final workspace = await _ArchiveWorkspace.open(inputPath);
    try {
      final issues = <EpubIssue>[];
      final mimetypeOk = _checkMimetype(workspace, issues);
      final container = _readContainer(workspace, issues, allowRecovery: false);
      _PackageContext? package;
      if (container != null) {
        package = _readPackage(
          workspace,
          container,
          issues,
          allowRecovery: false,
        );
      }

      var navigationOk = false;
      if (package != null) {
        _validatePackageReferences(workspace, package, issues);
        navigationOk = await _hasUsableNavigation(workspace, package);
        _inspectTextDocuments(workspace, package, issues);
      }

      return EpubInspection(
        inputPath: inputPath,
        entryCount: workspace.entries.length,
        packagePath: package?.opfPath,
        hasValidMimetype: mimetypeOk,
        hasValidContainer: container != null,
        hasValidPackage: package != null,
        hasUsableNavigation: navigationOk,
        issues: List.unmodifiable(issues),
      );
    } finally {
      await workspace.close();
    }
  }

  Future<EpubRepairResult> repair(
    String inputPath, {
    required String outputPath,
  }) async {
    final workspace = await _ArchiveWorkspace.open(inputPath);
    try {
      final issues = <EpubIssue>[];
      final changes = <EpubEntryChange>[];
      final mimetypeOk = _checkMimetype(workspace, issues);
      if (!mimetypeOk) {
        _repairMimetype(workspace, changes, issues);
      }

      final container = _readContainer(
        workspace,
        issues,
        allowRecovery: true,
        changes: changes,
      );
      if (container == null) {
        throw EpubRepairException(
          'Unable to identify an EPUB package document',
          issues: List.unmodifiable(issues),
        );
      }

      final package = _readPackage(
        workspace,
        container,
        issues,
        allowRecovery: true,
        changes: changes,
      );
      if (package == null) {
        throw EpubRepairException(
          'Unable to recover the EPUB package document',
          issues: List.unmodifiable(issues),
        );
      }

      await _repairXhtmlDocuments(workspace, package, changes, issues);
      await _repairNavigation(workspace, package, changes, issues);
      _validatePackageReferences(workspace, package, issues);

      if (issues.any((issue) => issue.severity == EpubIssueSeverity.fatal)) {
        throw EpubRepairException(
          'EPUB repair could not recover the package structure',
          issues: List.unmodifiable(issues),
        );
      }

      final changed = workspace.changed;
      await workspace.writeTo(outputPath, copyOnly: !changed);
      return EpubRepairResult(
        inputPath: inputPath,
        outputPath: outputPath,
        changed: changed,
        changes: List.unmodifiable(changes),
        issues: List.unmodifiable(issues),
      );
    } finally {
      await workspace.close();
    }
  }

  Future<EpubRepairResult> standardize(
    String inputPath, {
    required String outputPath,
  }) async {
    final workspace = await _ArchiveWorkspace.open(inputPath);
    try {
      final issues = <EpubIssue>[];
      final changes = <EpubEntryChange>[];
      if (!_checkMimetype(workspace, issues)) {
        _repairMimetype(workspace, changes, issues);
      }
      final container = _readContainer(
        workspace,
        issues,
        allowRecovery: true,
        changes: changes,
      );
      if (container == null) {
        throw EpubRepairException(
          'Unable to identify an EPUB package document',
          issues: List.unmodifiable(issues),
        );
      }
      var package = _readPackage(
        workspace,
        container,
        issues,
        allowRecovery: true,
        changes: changes,
      );
      if (package == null) {
        throw EpubRepairException(
          'Unable to recover the EPUB package document',
          issues: List.unmodifiable(issues),
        );
      }

      await _repairXhtmlDocuments(workspace, package, changes, issues);
      await _repairNavigation(workspace, package, changes, issues);
      final refreshedContainer = _readContainer(
        workspace,
        issues,
        allowRecovery: true,
        changes: changes,
      );
      if (refreshedContainer != null) {
        package = _readPackage(
          workspace,
          refreshedContainer,
          issues,
          allowRecovery: true,
          changes: changes,
        );
      }
      if (package == null) {
        throw EpubRepairException(
          'Unable to refresh the EPUB package after navigation repair',
          issues: List.unmodifiable(issues),
        );
      }
      _standardizeWorkspace(workspace, package, changes, issues);

      if (issues.any((issue) => issue.severity == EpubIssueSeverity.fatal)) {
        throw EpubRepairException(
          'EPUB standardization could not recover the package structure',
          issues: List.unmodifiable(issues),
        );
      }

      await workspace.writeTo(outputPath, copyOnly: !workspace.changed);
      return EpubRepairResult(
        inputPath: inputPath,
        outputPath: outputPath,
        changed: workspace.changed,
        changes: List.unmodifiable(changes),
        issues: List.unmodifiable(issues),
      );
    } finally {
      await workspace.close();
    }
  }
}

class _ArchiveWorkspace {
  _ArchiveWorkspace({
    required this.inputPath,
    required this.archive,
    required this.entries,
  }) : byPath = <String, _ArchiveEntry>{
         for (final entry in entries) entry.path: entry,
       };

  final String inputPath;
  final Archive archive;
  final List<_ArchiveEntry> entries;
  final Map<String, _ArchiveEntry> byPath;

  bool changed = false;

  static Future<_ArchiveWorkspace> open(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw StateError('EPUB file not found: $inputPath');
    }
    final bytes = await file.readAsBytes();
    final decoder = ZipDecoder();
    late final Archive archive;
    try {
      archive = decoder.decodeBytes(bytes);
    } catch (error) {
      throw EpubRepairException('Unable to read EPUB ZIP archive: $error');
    }

    final seen = <String>{};
    for (final header in decoder.directory.fileHeaders) {
      if (header.filename.endsWith('/') || header.filename.endsWith('\\')) {
        continue;
      }
      final path = _canonicalArchivePath(header.filename);
      if (path == null) {
        throw EpubRepairException(
          'Unsafe EPUB archive path: ${header.filename}',
          issues: <EpubIssue>[
            EpubIssue(
              code: 'unsafe_archive_path',
              severity: EpubIssueSeverity.fatal,
              action: EpubRepairAction.skipped,
              path: header.filename,
              message: 'Archive paths must remain inside the EPUB root.',
            ),
          ],
        );
      }
      if (!seen.add(path)) {
        throw EpubRepairException(
          'Duplicate EPUB archive path: $path',
          issues: <EpubIssue>[
            EpubIssue(
              code: 'duplicate_archive_path',
              severity: EpubIssueSeverity.fatal,
              action: EpubRepairAction.skipped,
              path: path,
              message:
                  'Duplicate paths are not safe to resolve deterministically.',
            ),
          ],
        );
      }
    }

    final entries = <_ArchiveEntry>[];
    for (final fileEntry in archive.files) {
      final path = _canonicalArchivePath(fileEntry.name);
      if (path == null || fileEntry.isDirectory) {
        continue;
      }
      entries.add(_ArchiveEntry(path: path, file: fileEntry));
    }
    return _ArchiveWorkspace(
      inputPath: file.absolute.path,
      archive: archive,
      entries: entries,
    );
  }

  _ArchiveEntry? entry(String path) => byPath[_canonicalArchivePath(path)];

  Uint8List? readBytes(String path) => entry(path)?.bytes;

  String? readText(String path) {
    final bytes = readBytes(path);
    return bytes == null ? null : _decodeText(bytes);
  }

  void replaceBytes(
    String path,
    Uint8List bytes, {
    required EpubRepairAction action,
    required String reason,
  }) {
    final target = entry(path);
    if (target == null) {
      throw StateError('Cannot replace missing EPUB entry: $path');
    }
    target.overrideBytes = bytes;
    changed = true;
  }

  void addBytes(String path, Uint8List bytes, {required String reason}) {
    final normalized = _canonicalArchivePath(path);
    if (normalized == null || byPath.containsKey(normalized)) {
      throw StateError('Cannot add duplicate or unsafe EPUB entry: $path');
    }
    final entry = _ArchiveEntry.synthetic(path: normalized, bytes: bytes);
    entries.add(entry);
    byPath[normalized] = entry;
    changed = true;
  }

  void rename(String oldPath, String newPath) {
    final entry = this.entry(oldPath);
    final normalized = _canonicalArchivePath(newPath);
    if (entry == null || normalized == null) {
      throw StateError('Cannot rename missing or unsafe EPUB entry');
    }
    if (entry.path == normalized) {
      return;
    }
    final existing = byPath[normalized];
    if (existing != null && existing != entry) {
      throw StateError('EPUB path collision: $normalized');
    }
    byPath.remove(entry.path);
    entry.outputPath = normalized;
    byPath[normalized] = entry;
    changed = true;
  }

  void applyPathMap(Map<String, String> pathMap) {
    final outputNames = <String>{};
    for (final entry in entries) {
      final outputPath = pathMap[entry.path] ?? entry.path;
      if (!outputNames.add(outputPath)) {
        throw StateError('EPUB path collision: $outputPath');
      }
    }
    for (final entry in entries) {
      final outputPath = pathMap[entry.path] ?? entry.path;
      if (entry.outputPath != outputPath) {
        entry.outputPath = outputPath;
        changed = true;
      }
    }
  }

  Future<void> writeTo(String outputPath, {required bool copyOnly}) async {
    final input = File(inputPath).absolute.path;
    final output = File(outputPath).absolute.path;
    if (_sameFilePath(input, output)) {
      throw ArgumentError('EPUB outputPath must differ from inputPath');
    }
    if (copyOnly) {
      await _copyAtomically(File(input), File(output));
      return;
    }

    final outputArchive = Archive();
    final ordered = List<_ArchiveEntry>.from(entries);
    ordered.sort((left, right) {
      final leftMimetype = left.outputPath == 'mimetype' ? 0 : 1;
      final rightMimetype = right.outputPath == 'mimetype' ? 0 : 1;
      return leftMimetype.compareTo(rightMimetype);
    });
    final outputNames = <String>{};
    for (final entry in ordered) {
      if (!outputNames.add(entry.outputPath)) {
        throw StateError('EPUB output path collision: ${entry.outputPath}');
      }
      outputArchive.add(entry.toArchiveFile());
    }

    final bytes = ZipEncoder().encodeBytes(outputArchive);
    await _writeBytesAtomically(File(output), Uint8List.fromList(bytes));
  }

  Future<void> close() async {
    await archive.clear();
  }
}

class _ArchiveEntry {
  _ArchiveEntry({required this.path, required this.file}) : outputPath = path;

  _ArchiveEntry.synthetic({required this.path, required Uint8List bytes})
    : file = null,
      outputPath = path,
      overrideBytes = bytes;

  final String path;
  final ArchiveFile? file;
  String outputPath;
  Uint8List? overrideBytes;

  Uint8List get bytes => overrideBytes ?? file!.content;

  ArchiveFile toArchiveFile() {
    final original = file;
    final replacement = overrideBytes;
    if (replacement == null && original != null) {
      original.name = outputPath;
      return original;
    }

    final result = outputPath == 'mimetype'
        ? ArchiveFile.noCompress(outputPath, replacement!.length, replacement)
        : ArchiveFile.bytes(outputPath, replacement!);
    if (original != null) {
      result
        ..mode = original.mode
        ..ownerId = original.ownerId
        ..lastModTime = original.lastModTime
        ..comment = original.comment;
      if (outputPath != 'mimetype' && original.compression != null) {
        result.compression = original.compression;
      }
    }
    return result;
  }
}

String? _canonicalArchivePath(String raw) {
  final replaced = raw.trim().replaceAll('\\', '/');
  if (replaced.isEmpty || replaced.startsWith('/')) {
    return null;
  }
  final normalized = p.posix.normalize(replaced);
  if (normalized == '.' || normalized == '..' || normalized.startsWith('../')) {
    return null;
  }
  return normalized;
}

String _decodeText(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var index = 0; index + 1 < bytes.length; index += 2) {
    final value = littleEndian
        ? bytes[index] | (bytes[index + 1] << 8)
        : (bytes[index] << 8) | bytes[index + 1];
    units.add(value);
  }
  return String.fromCharCodes(units);
}

bool _sameFilePath(String left, String right) {
  return p.normalize(left).toLowerCase() == p.normalize(right).toLowerCase();
}

Future<void> _copyAtomically(File source, File target) async {
  final parent = target.parent;
  if (!await parent.exists()) {
    await parent.create(recursive: true);
  }
  final temp = File(
    '${target.path}.__tmp__${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    await source.copy(temp.path);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  } catch (_) {
    if (await temp.exists()) {
      await temp.delete();
    }
    rethrow;
  }
}

Future<void> _writeBytesAtomically(File target, Uint8List bytes) async {
  final parent = target.parent;
  if (!await parent.exists()) {
    await parent.create(recursive: true);
  }
  final temp = File(
    '${target.path}.__tmp__${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  } catch (_) {
    if (await temp.exists()) {
      await temp.delete();
    }
    rethrow;
  }
}

class _ContainerContext {
  const _ContainerContext({
    required this.path,
    required this.document,
    required this.opfPath,
  });

  final String path;
  final XmlDocument document;
  final String opfPath;
}

class _ManifestItem {
  _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
    required this.fullPath,
    required this.element,
  });

  final String id;
  String href;
  final String mediaType;
  final List<String> properties;
  final String? fullPath;
  final XmlElement element;

  bool get isHtmlLike =>
      mediaType.toLowerCase() == 'application/xhtml+xml' ||
      mediaType.toLowerCase() == 'text/html';
}

class _SpineItem {
  const _SpineItem({
    required this.idRef,
    required this.linear,
    required this.element,
  });

  final String idRef;
  final bool linear;
  final XmlElement element;
}

class _PackageContext {
  _PackageContext({
    required this.opfPath,
    required this.document,
    required this.root,
    required this.manifestElement,
    required this.spineElement,
    required this.manifest,
    required this.spine,
    required this.version,
  });

  final String opfPath;
  final XmlDocument document;
  final XmlElement root;
  final XmlElement manifestElement;
  final XmlElement spineElement;
  final List<_ManifestItem> manifest;
  final List<_SpineItem> spine;
  final String? version;

  _ManifestItem? get navItem {
    for (final item in manifest) {
      if (item.properties.any((property) => property.toLowerCase() == 'nav')) {
        return item;
      }
    }
    return null;
  }

  _ManifestItem? get ncxItem {
    for (final item in manifest) {
      if (item.mediaType.toLowerCase() == 'application/x-dtbncx+xml') {
        return item;
      }
    }
    return null;
  }

  Map<String, _ManifestItem> get manifestById => <String, _ManifestItem>{
    for (final item in manifest) item.id: item,
  };
}

_ContainerContext? _readContainer(
  _ArchiveWorkspace workspace,
  List<EpubIssue> issues, {
  required bool allowRecovery,
  List<EpubEntryChange>? changes,
}) {
  final containerEntry = workspace.entry('META-INF/container.xml');
  if (containerEntry == null) {
    final candidates = workspace.entries
        .where((entry) => p.posix.extension(entry.path).toLowerCase() == '.opf')
        .toList(growable: false);
    if (!allowRecovery || candidates.length != 1) {
      issues.add(
        const EpubIssue(
          code: 'missing_container',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: 'META-INF/container.xml',
          message: 'META-INF/container.xml is missing or ambiguous.',
        ),
      );
      return null;
    }
    final opfPath = candidates.single.path;
    final xml = _buildContainerXml(opfPath);
    workspace.addBytes(
      'META-INF/container.xml',
      Uint8List.fromList(utf8.encode(xml)),
      reason: 'Created container.xml for the unique package document.',
    );
    changes?.add(
      const EpubEntryChange(
        path: 'META-INF/container.xml',
        action: EpubRepairAction.created,
        reason: 'Created from the unique .opf entry.',
      ),
    );
    issues.add(
      const EpubIssue(
        code: 'missing_container',
        severity: EpubIssueSeverity.warning,
        action: EpubRepairAction.created,
        path: 'META-INF/container.xml',
        message: 'Created container.xml from the unique package document.',
      ),
    );
    return _ContainerContext(
      path: 'META-INF/container.xml',
      document: XmlDocument.parse(xml),
      opfPath: opfPath,
    );
  }

  final source = _decodeText(containerEntry.bytes);
  XmlDocument? document;
  var recovered = false;
  try {
    document = XmlDocument.parse(source);
  } catch (_) {
    if (!allowRecovery) {
      issues.add(
        const EpubIssue(
          code: 'malformed_container',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: 'META-INF/container.xml',
          message: 'container.xml is not well-formed XML.',
        ),
      );
      return null;
    }
    try {
      document = XmlDocument.parse(
        repairMalformedXmlLike(source, expectedRoot: 'container'),
      );
      recovered = true;
    } catch (_) {
      issues.add(
        const EpubIssue(
          code: 'malformed_container',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: 'META-INF/container.xml',
          message: 'container.xml could not be recovered.',
        ),
      );
      return null;
    }
  }

  var rootFile = _findFirstXmlElement(document, 'rootfile');
  var opfPath = _attribute(rootFile, 'full-path');
  if (opfPath == null || opfPath.isEmpty) {
    final candidates = workspace.entries
        .where((entry) => p.posix.extension(entry.path).toLowerCase() == '.opf')
        .toList(growable: false);
    if (!allowRecovery || candidates.length != 1) {
      issues.add(
        const EpubIssue(
          code: 'missing_rootfile_path',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: 'META-INF/container.xml',
          message: 'container.xml has no unambiguous rootfile path.',
        ),
      );
      return null;
    }
    opfPath = candidates.single.path;
    rootFile = _ensureContainerRootfile(document, opfPath);
    recovered = true;
  }

  final resolved = _canonicalArchivePath(opfPath);
  if (resolved == null || workspace.entry(resolved) == null) {
    final candidates = workspace.entries
        .where((entry) => p.posix.extension(entry.path).toLowerCase() == '.opf')
        .toList(growable: false);
    if (!allowRecovery || candidates.length != 1) {
      issues.add(
        EpubIssue(
          code: 'missing_package_document',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: opfPath,
          message:
              'The container rootfile does not resolve to an archive entry.',
        ),
      );
      return null;
    }
    opfPath = candidates.single.path;
    rootFile = _ensureContainerRootfile(document, opfPath);
    recovered = true;
  } else {
    opfPath = resolved;
  }

  if (recovered) {
    workspace.replaceBytes(
      'META-INF/container.xml',
      Uint8List.fromList(utf8.encode(document.toXmlString(pretty: false))),
      action: EpubRepairAction.repaired,
      reason: 'Recovered container.xml structure.',
    );
    changes?.add(
      const EpubEntryChange(
        path: 'META-INF/container.xml',
        action: EpubRepairAction.repaired,
        reason: 'Recovered container.xml structure or rootfile path.',
      ),
    );
    issues.add(
      const EpubIssue(
        code: 'recovered_container',
        severity: EpubIssueSeverity.warning,
        action: EpubRepairAction.repaired,
        path: 'META-INF/container.xml',
        message: 'Recovered container.xml using a deterministic package path.',
      ),
    );
  }

  return _ContainerContext(
    path: 'META-INF/container.xml',
    document: document,
    opfPath: opfPath,
  );
}

String _buildContainerXml(String opfPath) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<container version="1.0" '
    'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
    '<rootfiles><rootfile full-path="${_escapeXml(opfPath)}" '
    'media-type="application/oebps-package+xml"/></rootfiles></container>';

XmlElement _ensureContainerRootfile(XmlDocument document, String opfPath) {
  final existing = _findFirstXmlElement(document, 'rootfile');
  if (existing != null) {
    existing.setAttribute('full-path', opfPath);
    return existing;
  }
  var rootfiles = _findFirstXmlElement(document, 'rootfiles');
  if (rootfiles == null) {
    rootfiles = XmlElement.tag('rootfiles', isSelfClosing: false);
    final container = _findFirstXmlElement(document, 'container');
    if (container == null) {
      throw const FormatException('container.xml has no container root');
    }
    container.children.add(rootfiles);
  }
  final rootfile = XmlElement.tag(
    'rootfile',
    attributes: <XmlAttribute>[
      XmlAttribute(XmlName('full-path'), opfPath),
      XmlAttribute(XmlName('media-type'), 'application/oebps-package+xml'),
    ],
  );
  rootfiles.children.add(rootfile);
  return rootfile;
}

_PackageContext? _readPackage(
  _ArchiveWorkspace workspace,
  _ContainerContext container,
  List<EpubIssue> issues, {
  required bool allowRecovery,
  List<EpubEntryChange>? changes,
}) {
  final packageEntry = workspace.entry(container.opfPath);
  if (packageEntry == null) {
    issues.add(
      EpubIssue(
        code: 'missing_package_document',
        severity: EpubIssueSeverity.fatal,
        action: EpubRepairAction.skipped,
        path: container.opfPath,
        message: 'The package document is missing from the archive.',
      ),
    );
    return null;
  }

  final source = _decodeText(packageEntry.bytes);
  XmlDocument? document;
  var recovered = false;
  try {
    document = XmlDocument.parse(source);
  } catch (_) {
    if (!allowRecovery) {
      issues.add(
        EpubIssue(
          code: 'malformed_package_document',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: container.opfPath,
          message: 'The package document is not well-formed XML.',
        ),
      );
      return null;
    }
    try {
      document = XmlDocument.parse(
        repairMalformedXmlLike(source, expectedRoot: 'package'),
      );
      recovered = true;
    } catch (_) {
      issues.add(
        EpubIssue(
          code: 'malformed_package_document',
          severity: EpubIssueSeverity.fatal,
          action: EpubRepairAction.skipped,
          path: container.opfPath,
          message: 'The package document could not be recovered.',
        ),
      );
      return null;
    }
  }

  final root = _findFirstXmlElement(document, 'package');
  if (root == null) {
    issues.add(
      EpubIssue(
        code: 'missing_package_root',
        severity: EpubIssueSeverity.fatal,
        action: EpubRepairAction.skipped,
        path: container.opfPath,
        message: 'The package document has no <package> root.',
      ),
    );
    return null;
  }

  var manifestElement = _findDirectXmlElement(root, 'manifest');
  var spineElement = _findDirectXmlElement(root, 'spine');
  if (allowRecovery &&
      (manifestElement == null ||
          _directXmlChildren(manifestElement, 'item').isEmpty ||
          spineElement == null ||
          _directXmlChildren(spineElement, 'itemref').isEmpty)) {
    final rebuilt = _ensurePackageStructure(
      workspace,
      root,
      manifestElement,
      spineElement,
      container.opfPath,
    );
    manifestElement = rebuilt.manifest;
    spineElement = rebuilt.spine;
    if (rebuilt.changed) {
      recovered = true;
      issues.add(
        EpubIssue(
          code: 'recovered_package_structure',
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.repaired,
          path: container.opfPath,
          message:
              'Rebuilt missing manifest or spine entries from archive content.',
        ),
      );
    }
  }

  if (manifestElement == null || spineElement == null) {
    issues.add(
      EpubIssue(
        code: 'missing_package_structure',
        severity: EpubIssueSeverity.fatal,
        action: EpubRepairAction.skipped,
        path: container.opfPath,
        message: 'The package document has no usable manifest and spine.',
      ),
    );
    return null;
  }

  final manifest = <_ManifestItem>[];
  for (final element in _directXmlChildren(manifestElement, 'item')) {
    final id = _attribute(element, 'id');
    final href = _attribute(element, 'href');
    final mediaType = _attribute(element, 'media-type');
    if (id == null ||
        id.isEmpty ||
        href == null ||
        href.isEmpty ||
        mediaType == null) {
      issues.add(
        EpubIssue(
          code: 'invalid_manifest_item',
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.skipped,
          path: container.opfPath,
          message: 'Skipped a manifest item without id, href, or media-type.',
        ),
      );
      continue;
    }
    final properties = (_attribute(element, 'properties') ?? '')
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    manifest.add(
      _ManifestItem(
        id: id,
        href: href,
        mediaType: mediaType,
        properties: properties,
        fullPath: _resolveInternalReference(container.opfPath, href),
        element: element,
      ),
    );
  }

  final byId = <String, _ManifestItem>{
    for (final item in manifest) item.id: item,
  };
  final spine = <_SpineItem>[];
  for (final element in _directXmlChildren(spineElement, 'itemref')) {
    final idRef = _attribute(element, 'idref');
    if (idRef == null || idRef.isEmpty) {
      continue;
    }
    spine.add(
      _SpineItem(
        idRef: idRef,
        linear: (_attribute(element, 'linear') ?? 'yes').toLowerCase() != 'no',
        element: element,
      ),
    );
    if (!byId.containsKey(idRef)) {
      issues.add(
        EpubIssue(
          code: 'missing_spine_manifest_item',
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.skipped,
          path: container.opfPath,
          message: 'Spine references missing manifest id "$idRef".',
        ),
      );
    }
  }

  if (manifest.isEmpty || spine.isEmpty) {
    issues.add(
      EpubIssue(
        code: 'empty_package_structure',
        severity: EpubIssueSeverity.fatal,
        action: EpubRepairAction.skipped,
        path: container.opfPath,
        message: 'The package document has an empty manifest or spine.',
      ),
    );
    return null;
  }

  if (recovered) {
    workspace.replaceBytes(
      container.opfPath,
      Uint8List.fromList(utf8.encode(document.toXmlString(pretty: false))),
      action: EpubRepairAction.repaired,
      reason: 'Recovered package XML structure.',
    );
    changes?.add(
      EpubEntryChange(
        path: container.opfPath,
        action: EpubRepairAction.repaired,
        reason: 'Recovered package XML structure.',
      ),
    );
  }

  return _PackageContext(
    opfPath: container.opfPath,
    document: document,
    root: root,
    manifestElement: manifestElement,
    spineElement: spineElement,
    manifest: manifest,
    spine: spine,
    version: _attribute(root, 'version'),
  );
}

class _PackageStructureResult {
  const _PackageStructureResult({
    required this.manifest,
    required this.spine,
    required this.changed,
  });

  final XmlElement? manifest;
  final XmlElement? spine;
  final bool changed;
}

_PackageStructureResult _ensurePackageStructure(
  _ArchiveWorkspace workspace,
  XmlElement root,
  XmlElement? manifest,
  XmlElement? spine,
  String opfPath,
) {
  var changed = false;
  manifest ??= XmlElement.tag('manifest', isSelfClosing: false);
  if (!root.children.contains(manifest)) {
    root.children.add(manifest);
    changed = true;
  }

  final htmlEntries = workspace.entries
      .where((entry) => _isHtmlPath(entry.path))
      .toList(growable: false);
  final existingIds = <String>{};
  final existingHrefs = <String>{};
  for (final item in _directXmlChildren(manifest, 'item')) {
    final id = _attribute(item, 'id');
    final href = _attribute(item, 'href');
    if (id != null && id.isNotEmpty) {
      existingIds.add(id);
    }
    if (href != null && href.isNotEmpty) {
      existingHrefs.add(href);
    }
  }
  for (final entry in htmlEntries) {
    final href = _relativeReference(opfPath, entry.path);
    if (existingHrefs.contains(href)) {
      continue;
    }
    var id = _slugId(p.posix.basenameWithoutExtension(entry.path));
    if (id.isEmpty) {
      id = 'item';
    }
    var suffix = 2;
    final baseId = id;
    while (!existingIds.add(id)) {
      id = '$baseId$suffix';
      suffix += 1;
    }
    final item = XmlElement.tag(
      'item',
      attributes: <XmlAttribute>[
        XmlAttribute(XmlName('id'), id),
        XmlAttribute(XmlName('href'), href),
        XmlAttribute(XmlName('media-type'), 'application/xhtml+xml'),
      ],
    );
    manifest.children.add(item);
    existingHrefs.add(href);
    changed = true;
  }

  spine ??= XmlElement.tag('spine', isSelfClosing: false);
  if (!root.children.contains(spine)) {
    root.children.add(spine);
    changed = true;
  }
  if (_directXmlChildren(spine, 'itemref').isEmpty) {
    for (final item in _directXmlChildren(manifest, 'item')) {
      final id = _attribute(item, 'id');
      final media = (_attribute(item, 'media-type') ?? '').toLowerCase();
      if (id == null ||
          (media != 'application/xhtml+xml' && media != 'text/html')) {
        continue;
      }
      spine.children.add(
        XmlElement.tag(
          'itemref',
          attributes: <XmlAttribute>[XmlAttribute(XmlName('idref'), id)],
        ),
      );
      changed = true;
    }
  }

  return _PackageStructureResult(
    manifest: manifest,
    spine: spine,
    changed: changed,
  );
}

bool _checkMimetype(_ArchiveWorkspace workspace, List<EpubIssue> issues) {
  final entry = workspace.entry('mimetype');
  if (entry == null) {
    issues.add(
      const EpubIssue(
        code: 'missing_mimetype',
        severity: EpubIssueSeverity.warning,
        action: EpubRepairAction.skipped,
        path: 'mimetype',
        message: 'The EPUB mimetype entry is missing.',
      ),
    );
    return false;
  }
  final valid =
      utf8.decode(entry.bytes, allowMalformed: true).trim() ==
      'application/epub+zip';
  if (!valid) {
    issues.add(
      const EpubIssue(
        code: 'invalid_mimetype',
        severity: EpubIssueSeverity.warning,
        action: EpubRepairAction.skipped,
        path: 'mimetype',
        message: 'The EPUB mimetype entry has unexpected content.',
      ),
    );
  }
  return valid;
}

void _repairMimetype(
  _ArchiveWorkspace workspace,
  List<EpubEntryChange> changes,
  List<EpubIssue> issues,
) {
  final bytes = Uint8List.fromList(utf8.encode('application/epub+zip'));
  if (workspace.entry('mimetype') == null) {
    workspace.addBytes('mimetype', bytes, reason: 'Created EPUB mimetype.');
    changes.add(
      const EpubEntryChange(
        path: 'mimetype',
        action: EpubRepairAction.created,
        reason: 'Created the required EPUB mimetype entry.',
      ),
    );
    issues.add(
      const EpubIssue(
        code: 'missing_mimetype',
        severity: EpubIssueSeverity.warning,
        action: EpubRepairAction.repaired,
        path: 'mimetype',
        message: 'Created the required EPUB mimetype entry.',
      ),
    );
    return;
  }
  workspace.replaceBytes(
    'mimetype',
    bytes,
    action: EpubRepairAction.repaired,
    reason: 'Replaced invalid EPUB mimetype.',
  );
  changes.add(
    const EpubEntryChange(
      path: 'mimetype',
      action: EpubRepairAction.repaired,
      reason: 'Replaced invalid EPUB mimetype content.',
    ),
  );
  issues.add(
    const EpubIssue(
      code: 'invalid_mimetype',
      severity: EpubIssueSeverity.warning,
      action: EpubRepairAction.repaired,
      path: 'mimetype',
      message: 'Replaced invalid EPUB mimetype content.',
    ),
  );
}

void _validatePackageReferences(
  _ArchiveWorkspace workspace,
  _PackageContext package,
  List<EpubIssue> issues,
) {
  for (final item in package.manifest) {
    final path = item.fullPath;
    if (path == null || workspace.entry(path) == null) {
      issues.add(
        EpubIssue(
          code: 'missing_manifest_target',
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.skipped,
          path: package.opfPath,
          message: 'Manifest item "${item.id}" does not resolve to a file.',
        ),
      );
    }
  }
  for (final item in package.spine) {
    if (!package.manifestById.containsKey(item.idRef)) {
      continue;
    }
    final manifestItem = package.manifestById[item.idRef]!;
    if (!manifestItem.isHtmlLike) {
      issues.add(
        EpubIssue(
          code: 'non_document_spine_item',
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.skipped,
          path: package.opfPath,
          message: 'Spine item "${item.idRef}" is not an XHTML document.',
        ),
      );
    }
  }
}

void _inspectTextDocuments(
  _ArchiveWorkspace workspace,
  _PackageContext package,
  List<EpubIssue> issues,
) {
  for (final item in package.manifest) {
    if (!item.isHtmlLike || item.fullPath == null) {
      continue;
    }
    final source = workspace.readText(item.fullPath!);
    if (source == null) {
      continue;
    }
    try {
      final document = XmlDocument.parse(source);
      if (_hasXhtmlXmlSyntaxIssue(source)) {
        issues.add(
          EpubIssue(
            code: 'malformed_xhtml',
            severity: EpubIssueSeverity.warning,
            action: EpubRepairAction.skipped,
            path: item.fullPath,
            message: 'XHTML contains HTML-only syntax that is invalid XML.',
          ),
        );
        continue;
      }
      final compatibilityIssue = _sigilXhtmlIssue(document);
      if (compatibilityIssue != null) {
        issues.add(
          EpubIssue(
            code: compatibilityIssue.code,
            severity: EpubIssueSeverity.warning,
            action: EpubRepairAction.skipped,
            path: item.fullPath,
            message: compatibilityIssue.message,
          ),
        );
      }
    } catch (_) {
      issues.add(
        EpubIssue(
          code: 'malformed_xhtml',
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.skipped,
          path: item.fullPath,
          message: 'XHTML is not well-formed XML and can be repaired.',
        ),
      );
    }
  }
}

Future<void> _repairXhtmlDocuments(
  _ArchiveWorkspace workspace,
  _PackageContext package,
  List<EpubEntryChange> changes,
  List<EpubIssue> issues,
) async {
  for (final item in package.manifest) {
    if (!item.isHtmlLike || item.fullPath == null) {
      continue;
    }
    final path = item.fullPath!;
    final entry = workspace.entry(path);
    if (entry == null) {
      continue;
    }
    final source = _decodeText(entry.bytes);
    try {
      final document = XmlDocument.parse(source);
      final hasXmlSyntaxIssue = _hasXhtmlXmlSyntaxIssue(source);
      final compatibilityIssue = _sigilXhtmlIssue(document);
      if (!hasXmlSyntaxIssue && compatibilityIssue == null) {
        continue;
      }

      final repaired = hasXmlSyntaxIssue
          ? repairMalformedXhtml(source, version: package.version)
          : compatibilityIssue!.code == 'missing_doctype'
          ? _insertXhtmlDoctype(source, package.version)
          : repairMalformedXhtml(source, version: package.version);
      final repairedDocument = XmlDocument.parse(repaired);
      final remainingIssue = _sigilXhtmlIssue(repairedDocument);
      if (remainingIssue != null) {
        throw FormatException(remainingIssue.message);
      }
      workspace.replaceBytes(
        path,
        Uint8List.fromList(utf8.encode(repaired)),
        action: EpubRepairAction.repaired,
        reason: 'Recovered Sigil-compatible XHTML structure.',
      );
      changes.add(
        EpubEntryChange(
          path: path,
          action: EpubRepairAction.repaired,
          reason: hasXmlSyntaxIssue
              ? 'Repaired HTML-only syntax that was invalid XML.'
              : compatibilityIssue!.message,
        ),
      );
      issues.add(
        EpubIssue(
          code: hasXmlSyntaxIssue
              ? 'malformed_xhtml'
              : compatibilityIssue!.code,
          severity: EpubIssueSeverity.warning,
          action: EpubRepairAction.repaired,
          path: path,
          message: hasXmlSyntaxIssue
              ? 'Repaired HTML-only syntax that was invalid XML.'
              : '${compatibilityIssue!.message} Repaired the XHTML document.',
        ),
      );
      continue;
    } catch (_) {
      try {
        final repaired = repairMalformedXhtml(source, version: package.version);
        final repairedDocument = XmlDocument.parse(repaired);
        final remainingIssue = _sigilXhtmlIssue(repairedDocument);
        if (remainingIssue != null) {
          throw FormatException(remainingIssue.message);
        }
        workspace.replaceBytes(
          path,
          Uint8List.fromList(utf8.encode(repaired)),
          action: EpubRepairAction.repaired,
          reason: 'Recovered malformed XHTML.',
        );
        changes.add(
          EpubEntryChange(
            path: path,
            action: EpubRepairAction.repaired,
            reason: 'Recovered malformed XHTML with a tolerant HTML parser.',
          ),
        );
        issues.add(
          EpubIssue(
            code: 'malformed_xhtml',
            severity: EpubIssueSeverity.warning,
            action: EpubRepairAction.repaired,
            path: path,
            message: 'Recovered malformed XHTML with XML-compatible output.',
          ),
        );
      } catch (error) {
        issues.add(
          EpubIssue(
            code: 'unrecoverable_xhtml',
            severity: EpubIssueSeverity.warning,
            action: EpubRepairAction.skipped,
            path: path,
            message: 'XHTML repair failed: $error',
          ),
        );
      }
    }
  }
}

class _XhtmlCompatibilityIssue {
  const _XhtmlCompatibilityIssue(this.code, this.message);

  final String code;
  final String message;
}

_XhtmlCompatibilityIssue? _sigilXhtmlIssue(XmlDocument document) {
  final doctype = document.doctypeElement;
  if (doctype == null || doctype.name.toLowerCase() != 'html') {
    return const _XhtmlCompatibilityIssue(
      'missing_doctype',
      'XHTML is missing the HTML DOCTYPE expected by Sigil.',
    );
  }

  final root = document.rootElement;
  if (root.name.local.toLowerCase() != 'html') {
    return const _XhtmlCompatibilityIssue(
      'missing_html_root',
      'XHTML has no <html> document root.',
    );
  }
  if (_findDirectXmlElement(root, 'head') == null) {
    return const _XhtmlCompatibilityIssue(
      'missing_head',
      'XHTML is missing its <head> element.',
    );
  }
  if (_findDirectXmlElement(root, 'body') == null) {
    return const _XhtmlCompatibilityIssue(
      'missing_body',
      'XHTML is missing its <body> element.',
    );
  }
  return null;
}

String _insertXhtmlDoctype(String source, String? version) {
  final doctype = version?.startsWith('2') == true
      ? '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" '
            '"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
      : '<!DOCTYPE html>';
  final declaration = RegExp(
    r'^\s*<\?xml\b[\s\S]*?\?>',
    caseSensitive: false,
  ).firstMatch(source);
  if (declaration == null) {
    return '$doctype\n$source';
  }
  return '${source.substring(0, declaration.end)}\n$doctype'
      '${source.substring(declaration.end)}';
}

bool _hasXhtmlXmlSyntaxIssue(String source) {
  var index = 0;
  while (index < source.length) {
    final open = source.indexOf('<', index);
    if (open < 0) {
      return false;
    }
    if (source.startsWith('<!--', open)) {
      final close = source.indexOf('-->', open + 4);
      if (close < 0) {
        return true;
      }
      index = close + 3;
      continue;
    }
    if (source.startsWith('<![CDATA[', open)) {
      final close = source.indexOf(']]>', open + 9);
      if (close < 0) {
        return true;
      }
      index = close + 3;
      continue;
    }
    if (source.startsWith('<?', open)) {
      final close = source.indexOf('?>', open + 2);
      if (close < 0) {
        return true;
      }
      index = close + 2;
      continue;
    }
    if (source.startsWith('<!', open)) {
      final close = source.indexOf('>', open + 2);
      if (close < 0) {
        return true;
      }
      index = close + 1;
      continue;
    }

    var cursor = open + 1;
    if (cursor >= source.length) {
      return true;
    }
    if (source.codeUnitAt(cursor) == 47) {
      cursor += 1;
      while (cursor < source.length &&
          _isXmlWhitespace(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      if (cursor >= source.length ||
          !_isXmlNameStart(source.codeUnitAt(cursor))) {
        return true;
      }
      cursor += 1;
      while (cursor < source.length && _isXmlName(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      while (cursor < source.length &&
          _isXmlWhitespace(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      if (cursor >= source.length || source.codeUnitAt(cursor) != 62) {
        return true;
      }
      index = cursor + 1;
      continue;
    }
    if (!_isXmlNameStart(source.codeUnitAt(cursor))) {
      return true;
    }
    cursor += 1;
    while (cursor < source.length && _isXmlName(source.codeUnitAt(cursor))) {
      cursor += 1;
    }

    while (true) {
      while (cursor < source.length &&
          _isXmlWhitespace(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      if (cursor >= source.length) {
        return true;
      }
      final character = source.codeUnitAt(cursor);
      if (character == 62) {
        index = cursor + 1;
        break;
      }
      if (character == 47) {
        if (cursor + 1 >= source.length ||
            source.codeUnitAt(cursor + 1) != 62) {
          return true;
        }
        index = cursor + 2;
        break;
      }
      if (!_isXmlNameStart(character)) {
        return true;
      }
      cursor += 1;
      while (cursor < source.length && _isXmlName(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      while (cursor < source.length &&
          _isXmlWhitespace(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      if (cursor >= source.length || source.codeUnitAt(cursor) != 61) {
        return true;
      }
      cursor += 1;
      while (cursor < source.length &&
          _isXmlWhitespace(source.codeUnitAt(cursor))) {
        cursor += 1;
      }
      if (cursor >= source.length ||
          (source.codeUnitAt(cursor) != 34 &&
              source.codeUnitAt(cursor) != 39)) {
        return true;
      }
      final quote = source.codeUnitAt(cursor);
      cursor += 1;
      while (cursor < source.length && source.codeUnitAt(cursor) != quote) {
        cursor += 1;
      }
      if (cursor >= source.length) {
        return true;
      }
      cursor += 1;
    }
  }
  return false;
}

bool _isXmlWhitespace(int codeUnit) =>
    codeUnit == 9 ||
    codeUnit == 10 ||
    codeUnit == 12 ||
    codeUnit == 13 ||
    codeUnit == 32;

bool _isXmlNameStart(int codeUnit) =>
    codeUnit == 58 ||
    codeUnit == 95 ||
    codeUnit >= 65 && codeUnit <= 90 ||
    codeUnit >= 97 && codeUnit <= 122;

bool _isXmlName(int codeUnit) =>
    _isXmlNameStart(codeUnit) ||
    codeUnit == 45 ||
    codeUnit == 46 ||
    codeUnit >= 48 && codeUnit <= 57;

class _NavigationTarget {
  const _NavigationTarget({
    required this.title,
    required this.href,
    this.level = 0,
  });

  final String title;
  final String href;
  final int level;
}

Future<bool> _hasUsableNavigation(
  _ArchiveWorkspace workspace,
  _PackageContext package,
) async {
  final nav = package.navItem;
  if (nav?.fullPath != null) {
    final targets = _readNavTargets(workspace, nav!.fullPath!);
    if (targets.isNotEmpty) {
      return true;
    }
  }
  final ncx = package.ncxItem;
  if (ncx?.fullPath != null) {
    final targets = _readNcxTargets(workspace, ncx!.fullPath!);
    if (targets.isNotEmpty) {
      return true;
    }
  }
  return false;
}

List<_NavigationTarget> _readNavTargets(
  _ArchiveWorkspace workspace,
  String fullPath,
) {
  final source = workspace.readText(fullPath);
  if (source == null) {
    return const <_NavigationTarget>[];
  }
  try {
    final document = XmlDocument.parse(source);
    final navElements = _findAllXmlElements(document, 'nav');
    XmlElement? nav;
    for (final candidate in navElements) {
      final type =
          _attribute(candidate, 'epub:type') ??
          _attribute(candidate, 'type') ??
          '';
      if (type.toLowerCase().contains('toc')) {
        nav = candidate;
        break;
      }
    }
    nav ??= navElements.isEmpty ? null : navElements.first;
    if (nav == null) {
      return const <_NavigationTarget>[];
    }
    final list = _findDirectXmlElement(nav, 'ol');
    if (list == null) {
      return const <_NavigationTarget>[];
    }
    final targets = <_NavigationTarget>[];
    void visit(XmlElement current, int level) {
      for (final li in _directXmlChildren(current, 'li')) {
        final link = _findFirstXmlElement(li, 'a');
        final href = _attribute(link, 'href');
        final title = link?.innerText.trim() ?? '';
        if (href != null && href.isNotEmpty && title.isNotEmpty) {
          targets.add(
            _NavigationTarget(title: title, href: href, level: level),
          );
        }
        final childList = _findDirectXmlElement(li, 'ol');
        if (childList != null) {
          visit(childList, level + 1);
        }
      }
    }

    visit(list, 0);
    return targets;
  } catch (_) {
    return const <_NavigationTarget>[];
  }
}

List<_NavigationTarget> _readNcxTargets(
  _ArchiveWorkspace workspace,
  String fullPath,
) {
  final source = workspace.readText(fullPath);
  if (source == null) {
    return const <_NavigationTarget>[];
  }
  try {
    final document = XmlDocument.parse(source);
    final navMap = _findFirstXmlElement(document, 'navMap');
    if (navMap == null) {
      return const <_NavigationTarget>[];
    }
    final targets = <_NavigationTarget>[];
    void visit(XmlElement navPoint, int level) {
      final label =
          _findFirstXmlElement(navPoint, 'text')?.innerText.trim() ?? '';
      final content = _findFirstXmlElement(navPoint, 'content');
      final href = _attribute(content, 'src');
      if (href != null && href.isNotEmpty && label.isNotEmpty) {
        targets.add(_NavigationTarget(title: label, href: href, level: level));
      }
      for (final child in _directXmlChildren(navPoint, 'navPoint')) {
        visit(child, level + 1);
      }
    }

    for (final navPoint in _directXmlChildren(navMap, 'navPoint')) {
      visit(navPoint, 0);
    }
    return targets;
  } catch (_) {
    return const <_NavigationTarget>[];
  }
}

Future<void> _repairNavigation(
  _ArchiveWorkspace workspace,
  _PackageContext package,
  List<EpubEntryChange> changes,
  List<EpubIssue> issues,
) async {
  final nav = package.navItem;
  if (nav?.fullPath != null &&
      _readNavTargets(workspace, nav!.fullPath!).isNotEmpty) {
    return;
  }
  final ncx = package.ncxItem;
  if (ncx?.fullPath != null &&
      _readNcxTargets(workspace, ncx!.fullPath!).isNotEmpty) {
    return;
  }

  final headings = _collectHeadings(workspace, package);
  if (headings.isEmpty) {
    issues.add(
      const EpubIssue(
        code: 'missing_navigation_source',
        severity: EpubIssueSeverity.warning,
        action: EpubRepairAction.skipped,
        message:
            'No high-confidence headings were found for navigation repair.',
      ),
    );
    return;
  }

  final version = double.tryParse(package.version ?? '');
  final useNav =
      nav != null || (ncx == null && (version == null || version >= 3));
  final targetPath = useNav
      ? (nav?.fullPath ?? _uniquePath(workspace, 'OEBPS/nav.xhtml', package))
      : (ncx?.fullPath ?? _uniquePath(workspace, 'OEBPS/toc.ncx', package));
  final source = useNav
      ? _buildNavXml(targetPath, headings, package)
      : _buildNcxXml(targetPath, headings, package);
  final bytes = Uint8List.fromList(utf8.encode(source));

  if (workspace.entry(targetPath) == null) {
    workspace.addBytes(
      targetPath,
      bytes,
      reason: 'Created missing navigation.',
    );
    changes.add(
      EpubEntryChange(
        path: targetPath,
        action: EpubRepairAction.created,
        reason: 'Created navigation from high-confidence headings.',
      ),
    );
  } else {
    workspace.replaceBytes(
      targetPath,
      bytes,
      action: EpubRepairAction.repaired,
      reason: 'Rebuilt unusable navigation.',
    );
    changes.add(
      EpubEntryChange(
        path: targetPath,
        action: EpubRepairAction.repaired,
        reason: 'Rebuilt unusable navigation from headings.',
      ),
    );
  }

  final item = useNav ? nav : ncx;
  var navigationId = item?.id;
  if (item == null) {
    var id = useNav ? 'nav' : 'ncx';
    final ids = <String>{for (final existing in package.manifest) existing.id};
    var suffix = 2;
    final baseId = id;
    while (!ids.add(id)) {
      id = '$baseId$suffix';
      suffix += 1;
    }
    final element = XmlElement.tag(
      'item',
      attributes: <XmlAttribute>[
        XmlAttribute(XmlName('id'), id),
        XmlAttribute(
          XmlName('href'),
          _relativeReference(package.opfPath, targetPath),
        ),
        XmlAttribute(
          XmlName('media-type'),
          useNav ? 'application/xhtml+xml' : 'application/x-dtbncx+xml',
        ),
        if (useNav) XmlAttribute(XmlName('properties'), 'nav'),
      ],
    );
    package.manifestElement.children.add(element);
    navigationId = id;
  } else {
    item.element.setAttribute(
      'href',
      _relativeReference(package.opfPath, targetPath),
    );
    item.element.setAttribute(
      'media-type',
      useNav ? 'application/xhtml+xml' : 'application/x-dtbncx+xml',
    );
    if (useNav) {
      item.element.setAttribute('properties', 'nav');
    }
  }
  if (!useNav) {
    package.spineElement.setAttribute('toc', navigationId ?? 'ncx');
  }

  workspace.replaceBytes(
    package.opfPath,
    Uint8List.fromList(
      utf8.encode(package.document.toXmlString(pretty: false)),
    ),
    action: EpubRepairAction.repaired,
    reason: 'Added or repaired the navigation manifest entry.',
  );
  changes.add(
    EpubEntryChange(
      path: package.opfPath,
      action: EpubRepairAction.repaired,
      reason: 'Added or repaired the navigation manifest entry.',
    ),
  );
  issues.add(
    EpubIssue(
      code: 'missing_navigation',
      severity: EpubIssueSeverity.warning,
      action: EpubRepairAction.repaired,
      path: targetPath,
      message: 'Created navigation from high-confidence document headings.',
    ),
  );
}

List<_NavigationTarget> _collectHeadings(
  _ArchiveWorkspace workspace,
  _PackageContext package,
) {
  final headings = <_NavigationTarget>[];
  final seen = <String>{};
  for (final spineItem in package.spine) {
    if (!spineItem.linear) {
      continue;
    }
    final manifestItem = package.manifestById[spineItem.idRef];
    final path = manifestItem?.fullPath;
    if (manifestItem == null || path == null || !manifestItem.isHtmlLike) {
      continue;
    }
    final source = workspace.readText(path);
    if (source == null) {
      continue;
    }
    XmlDocument document;
    try {
      document = XmlDocument.parse(source);
    } catch (_) {
      continue;
    }
    for (final element in document.descendants.whereType<XmlElement>()) {
      final local = element.name.local.toLowerCase();
      if (local != 'h1' && local != 'h2' && local != 'h3') {
        continue;
      }
      final title = _cleanHeadingTitle(element.innerText);
      if (!_isUsableHeadingTitle(title, path)) {
        continue;
      }
      final id = _attribute(element, 'id');
      final key = '$path#${id ?? ''}';
      if (!seen.add(key)) {
        continue;
      }
      final href = id == null || id.isEmpty ? path : '$path#$id';
      headings.add(_NavigationTarget(title: title, href: href));
    }
  }
  return headings;
}

String _cleanHeadingTitle(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _isUsableHeadingTitle(String title, String path) {
  if (title.isEmpty) {
    return false;
  }
  final fileName = p.posix.basenameWithoutExtension(path).toLowerCase();
  final normalizedTitle = title.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (normalizedTitle == fileName) {
    return false;
  }
  if (RegExp(r'^[a-z]{1,4}[0-9]+$').hasMatch(normalizedTitle)) {
    return false;
  }
  return true;
}

String _uniquePath(
  _ArchiveWorkspace workspace,
  String preferred,
  _PackageContext package,
) {
  final root = p.posix.dirname(package.opfPath);
  final candidate = root.isEmpty
      ? p.posix.basename(preferred)
      : p.posix.join(root, p.posix.basename(preferred));
  if (workspace.entry(candidate) == null) {
    return candidate;
  }
  final extension = p.posix.extension(candidate);
  final stem = candidate.substring(0, candidate.length - extension.length);
  var index = 2;
  while (workspace.entry('$stem-$index$extension') != null) {
    index += 1;
  }
  return '$stem-$index$extension';
}

String _buildNavXml(
  String navPath,
  List<_NavigationTarget> headings,
  _PackageContext package,
) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<html xmlns="http://www.w3.org/1999/xhtml" '
    'xmlns:epub="http://www.idpf.org/2007/ops"><head>'
    '<title>Contents</title></head><body><nav epub:type="toc">'
    '<h1>Contents</h1><ol>',
  );
  for (final heading in headings) {
    final href =
        _relativeReference(navPath, _stripFragment(heading.href)) +
        _fragmentOf(heading.href);
    buffer
      ..write('<li><a href="')
      ..write(_escapeXml(href))
      ..write('">')
      ..write(_escapeXml(heading.title))
      ..write('</a></li>');
  }
  buffer.write('</ol></nav></body></html>');
  return buffer.toString();
}

String _buildNcxXml(
  String ncxPath,
  List<_NavigationTarget> headings,
  _PackageContext package,
) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
    '<head></head><docTitle><text>Contents</text></docTitle><navMap>',
  );
  for (var index = 0; index < headings.length; index += 1) {
    final heading = headings[index];
    final href =
        _relativeReference(ncxPath, _stripFragment(heading.href)) +
        _fragmentOf(heading.href);
    buffer
      ..write('<navPoint id="navPoint-')
      ..write(index + 1)
      ..write('" playOrder="')
      ..write(index + 1)
      ..write('"><navLabel><text>')
      ..write(_escapeXml(heading.title))
      ..write('</text></navLabel><content src="')
      ..write(_escapeXml(href))
      ..write('"/></navPoint>');
  }
  buffer.write('</navMap></ncx>');
  return buffer.toString();
}

void _standardizeWorkspace(
  _ArchiveWorkspace workspace,
  _PackageContext package,
  List<EpubEntryChange> changes,
  List<EpubIssue> issues,
) {
  const targetOpfPath = 'OEBPS/content.opf';
  final pathMap = <String, String>{package.opfPath: targetOpfPath};
  final reserved = <String>{targetOpfPath};

  final nav = package.navItem;
  if (nav?.fullPath != null) {
    pathMap[nav!.fullPath!] = 'OEBPS/nav.xhtml';
    reserved.add('OEBPS/nav.xhtml');
  }
  final ncx = package.ncxItem;
  if (ncx?.fullPath != null) {
    pathMap[ncx!.fullPath!] = 'OEBPS/toc.ncx';
    reserved.add('OEBPS/toc.ncx');
  }

  final manifestByPath = <String, _ManifestItem>{
    for (final item in package.manifest)
      if (item.fullPath != null) item.fullPath!: item,
  };
  for (final entry in workspace.entries) {
    if (entry.path == 'mimetype' || entry.path.startsWith('META-INF/')) {
      continue;
    }
    if (pathMap.containsKey(entry.path)) {
      continue;
    }
    final item = manifestByPath[entry.path];
    final directory = _standardDirectory(
      item?.mediaType ?? _mediaTypeForPath(entry.path),
    );
    final candidate = _uniqueStandardPath(
      'OEBPS/$directory/${p.posix.basename(entry.path)}',
      reserved,
    );
    pathMap[entry.path] = candidate;
    reserved.add(candidate);
  }

  for (final entry in List<_ArchiveEntry>.from(workspace.entries)) {
    final oldPath = entry.path;
    final newPath = pathMap[oldPath] ?? oldPath;
    if (_isXmlLikePath(oldPath) || _isCssPath(oldPath)) {
      final source = _decodeText(entry.bytes);
      final rewritten = _rewriteReferences(
        source,
        oldPath: oldPath,
        newPath: newPath,
        pathMap: pathMap,
        isCss: _isCssPath(oldPath),
      );
      if (rewritten != null && rewritten != source) {
        workspace.replaceBytes(
          oldPath,
          Uint8List.fromList(utf8.encode(rewritten)),
          action: EpubRepairAction.repaired,
          reason: 'Updated references after EPUB standardization.',
        );
        changes.add(
          EpubEntryChange(
            path: oldPath,
            action: EpubRepairAction.repaired,
            reason: 'Updated references after EPUB standardization.',
          ),
        );
      }
    }
  }

  for (final item in package.manifest) {
    final oldPath = item.fullPath;
    final newPath = oldPath == null ? null : pathMap[oldPath];
    if (newPath != null) {
      item.element.setAttribute(
        'href',
        _relativeReference(targetOpfPath, newPath),
      );
    }
  }
  final packageBytes = Uint8List.fromList(
    utf8.encode(package.document.toXmlString(pretty: false)),
  );
  final packageEntry = workspace.entry(package.opfPath)!;
  if (!_sameBytes(packageEntry.bytes, packageBytes)) {
    workspace.replaceBytes(
      package.opfPath,
      packageBytes,
      action: EpubRepairAction.repaired,
      reason: 'Updated the package document for the standardized layout.',
    );
    if (package.opfPath == targetOpfPath) {
      changes.add(
        const EpubEntryChange(
          path: 'OEBPS/content.opf',
          action: EpubRepairAction.repaired,
          reason: 'Updated package references for the standardized layout.',
        ),
      );
    }
  }
  if (package.opfPath != targetOpfPath) {
    changes.add(
      EpubEntryChange(
        path: package.opfPath,
        outputPath: targetOpfPath,
        action: EpubRepairAction.moved,
        reason: 'Moved the package document to OEBPS/content.opf.',
      ),
    );
  }

  final containerBytes = Uint8List.fromList(
    utf8.encode(_buildContainerXml(targetOpfPath)),
  );
  final containerEntry = workspace.entry('META-INF/container.xml')!;
  if (!_sameBytes(containerEntry.bytes, containerBytes)) {
    workspace.replaceBytes(
      'META-INF/container.xml',
      containerBytes,
      action: EpubRepairAction.repaired,
      reason: 'Updated the container rootfile path.',
    );
    changes.add(
      const EpubEntryChange(
        path: 'META-INF/container.xml',
        action: EpubRepairAction.repaired,
        reason: 'Updated the container rootfile path.',
      ),
    );
  }

  workspace.applyPathMap(pathMap);
  for (final entry in workspace.entries) {
    if (entry.path != entry.outputPath) {
      changes.add(
        EpubEntryChange(
          path: entry.path,
          outputPath: entry.outputPath,
          action: EpubRepairAction.moved,
          reason: 'Moved entry to the Sigil-compatible OEBPS layout.',
        ),
      );
    }
  }
  issues.add(
    const EpubIssue(
      code: 'standardized_layout',
      severity: EpubIssueSeverity.info,
      action: EpubRepairAction.moved,
      message:
          'Applied the explicit OEBPS standard layout and updated references.',
    ),
  );
}

String _standardDirectory(String mediaType) {
  final lower = mediaType.toLowerCase();
  if (lower == 'application/xhtml+xml' ||
      lower == 'text/html' ||
      lower.endsWith('+html')) {
    return 'Text';
  }
  if (lower == 'text/css') {
    return 'Styles';
  }
  if (lower.startsWith('image/')) {
    return 'Images';
  }
  if (lower.startsWith('font/') ||
      lower.contains('opentype') ||
      lower.contains('truetype') ||
      lower.contains('woff')) {
    return 'Fonts';
  }
  if (lower.startsWith('audio/')) {
    return 'Audio';
  }
  if (lower.startsWith('video/')) {
    return 'Video';
  }
  return 'Misc';
}

String _mediaTypeForPath(String path) {
  switch (p.posix.extension(path).toLowerCase()) {
    case '.xhtml':
    case '.html':
    case '.htm':
      return 'application/xhtml+xml';
    case '.css':
      return 'text/css';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
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
    case '.mp3':
      return 'audio/mpeg';
    case '.mp4':
      return 'video/mp4';
    default:
      return 'application/octet-stream';
  }
}

String _uniqueStandardPath(String preferred, Set<String> reserved) {
  if (!reserved.contains(preferred)) {
    return preferred;
  }
  final extension = p.posix.extension(preferred);
  final stem = preferred.substring(0, preferred.length - extension.length);
  var suffix = 2;
  while (reserved.contains('$stem-$suffix$extension')) {
    suffix += 1;
  }
  return '$stem-$suffix$extension';
}

String? _rewriteReferences(
  String source, {
  required String oldPath,
  required String newPath,
  required Map<String, String> pathMap,
  required bool isCss,
}) {
  if (isCss) {
    final rewritten = source.replaceAllMapped(
      RegExp(r'''url\(\s*(['"]?)([^'")]+)\1\s*\)''', caseSensitive: false),
      (match) {
        final quote = match.group(1) ?? '';
        final value = match.group(2)!.trim();
        final replacement = _rewriteReference(
          value,
          oldFilePath: oldPath,
          newFilePath: newPath,
          pathMap: pathMap,
        );
        return 'url($quote$replacement$quote)';
      },
    );
    return rewritten;
  }

  XmlDocument document;
  try {
    document = XmlDocument.parse(source);
  } catch (_) {
    return null;
  }
  var changed = false;
  final elements = <XmlElement>[];
  final root = document.rootElement;
  elements.add(root);
  elements.addAll(document.descendants.whereType<XmlElement>());
  for (final element in elements) {
    for (final attribute in element.attributes) {
      final local = attribute.name.local.toLowerCase();
      final qualified = attribute.name.qualified.toLowerCase();
      final isReference =
          local == 'href' ||
          local == 'src' ||
          local == 'poster' ||
          local == 'data' ||
          local == 'cite' ||
          local == 'longdesc' ||
          qualified == 'xlink:href';
      if (isReference) {
        final replacement = _rewriteReference(
          attribute.value,
          oldFilePath: oldPath,
          newFilePath: newPath,
          pathMap: pathMap,
        );
        if (replacement != attribute.value) {
          attribute.value = replacement;
          changed = true;
        }
      } else if (local == 'style') {
        final replacement = _rewriteReferences(
          attribute.value,
          oldPath: oldPath,
          newPath: newPath,
          pathMap: pathMap,
          isCss: true,
        );
        if (replacement != null && replacement != attribute.value) {
          attribute.value = replacement;
          changed = true;
        }
      }
    }
    if (element.name.local.toLowerCase() == 'style') {
      for (final text in element.children.whereType<XmlText>()) {
        final replacement = _rewriteReferences(
          text.value,
          oldPath: oldPath,
          newPath: newPath,
          pathMap: pathMap,
          isCss: true,
        );
        if (replacement != null && replacement != text.value) {
          text.value = replacement;
          changed = true;
        }
      }
    }
  }
  return changed ? document.toXmlString(pretty: false) : source;
}

String _rewriteReference(
  String raw, {
  required String oldFilePath,
  required String newFilePath,
  required Map<String, String> pathMap,
}) {
  final value = raw.trim();
  if (value.isEmpty ||
      value.startsWith('#') ||
      value.startsWith('//') ||
      value.startsWith('data:') ||
      value.startsWith('mailto:') ||
      RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(value)) {
    return raw;
  }
  final fragment = _fragmentOf(value);
  final pathPart = _stripFragment(value);
  final resolved = _resolveInternalReference(oldFilePath, pathPart);
  if (resolved == null) {
    return raw;
  }
  final mapped = pathMap[resolved];
  if (mapped == null) {
    return raw;
  }
  return _relativeReference(newFilePath, mapped) + fragment;
}

String _relativeReference(String fromFilePath, String targetPath) {
  final fromDir = p.posix.dirname(fromFilePath);
  final relative = p.posix.relative(targetPath, from: fromDir);
  return relative == '.' ? p.posix.basename(targetPath) : relative;
}

String _stripFragment(String value) {
  final index = value.indexOf('#');
  return index < 0 ? value : value.substring(0, index);
}

String _fragmentOf(String value) {
  final index = value.indexOf('#');
  return index < 0 ? '' : value.substring(index);
}

String? _resolveInternalReference(String baseFilePath, String rawReference) {
  final reference = rawReference.trim().replaceAll('\\', '/');
  if (reference.isEmpty) {
    return _canonicalArchivePath(baseFilePath);
  }
  if (reference.startsWith('/') ||
      reference.startsWith('#') ||
      reference.startsWith('data:') ||
      RegExp(
        r'^[a-z][a-z0-9+.-]*:',
        caseSensitive: false,
      ).hasMatch(reference)) {
    return null;
  }
  final joined = p.posix.normalize(
    p.posix.join(p.posix.dirname(baseFilePath), reference),
  );
  return _canonicalArchivePath(joined);
}

bool _isHtmlPath(String path) {
  final extension = p.posix.extension(path).toLowerCase();
  return extension == '.xhtml' || extension == '.html' || extension == '.htm';
}

bool _isCssPath(String path) => p.posix.extension(path).toLowerCase() == '.css';

bool _isXmlLikePath(String path) {
  final extension = p.posix.extension(path).toLowerCase();
  return extension == '.xhtml' ||
      extension == '.html' ||
      extension == '.htm' ||
      extension == '.xml' ||
      extension == '.opf' ||
      extension == '.ncx';
}

String _slugId(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? 'item' : slug;
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String? _attribute(XmlElement? element, String name) {
  if (element == null) {
    return null;
  }
  final exact = element.getAttribute(name);
  if (exact != null) {
    return exact.trim();
  }
  final lower = name.toLowerCase();
  for (final attribute in element.attributes) {
    if (attribute.name.local.toLowerCase() == lower) {
      return attribute.value.trim();
    }
  }
  return null;
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

XmlElement? _findFirstXmlElement(XmlNode node, String localName) {
  for (final element in _findAllXmlElements(node, localName)) {
    return element;
  }
  return null;
}

List<XmlElement> _findAllXmlElements(XmlNode node, String localName) {
  final lower = localName.toLowerCase();
  return <XmlElement>[
    if (node is XmlElement && node.name.local.toLowerCase() == lower) node,
    ...node.descendants.whereType<XmlElement>().where(
      (element) => element.name.local.toLowerCase() == lower,
    ),
  ];
}

XmlElement? _findDirectXmlElement(XmlElement node, String localName) {
  final lower = localName.toLowerCase();
  for (final child in node.children.whereType<XmlElement>()) {
    if (child.name.local.toLowerCase() == lower) {
      return child;
    }
  }
  return null;
}

List<XmlElement> _directXmlChildren(XmlElement node, String localName) {
  final lower = localName.toLowerCase();
  return node.children
      .whereType<XmlElement>()
      .where((child) => child.name.local.toLowerCase() == lower)
      .toList(growable: false);
}
