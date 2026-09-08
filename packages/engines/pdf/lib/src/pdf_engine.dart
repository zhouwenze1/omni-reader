import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_view.dart';

class PdfReaderEngine extends ReaderEngine {
  static const Set<String> _formats = <String>{'pdf'};

  static const Set<ReaderCapability> _capabilities = <ReaderCapability>{
    ReaderCapability.linearNavigation,
    ReaderCapability.jumpNavigation,
    ReaderCapability.style,
    ReaderCapability.theme,
  };

  @override
  String get id => 'pdf';

  @override
  String get displayName => 'PDF';

  @override
  Set<String> get supportedFormats => _formats;

  @override
  Set<ReaderCapability> get capabilities => _capabilities;

  @override
  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
    ReaderStyle initialStyle = ReaderStyle.defaults,
    String? initialLayoutMode,
  }) async {
    return PdfReaderSession(
      book: book,
      initialProgress: initialProgress,
      initialStyle: initialStyle,
      initialLayoutMode: initialLayoutMode,
    );
  }
}

/// PDF 阅读会话:页 = PDF 页,复用漫画的页式交互(单页/双页/滚动、翻页、
/// 进度恢复、整页书签/笔记)。渲染交给 pdfrx(PDFium)。
class PdfReaderSession extends ReaderSession {
  PdfReaderSession({
    required Book book,
    this.initialProgress,
    required ReaderStyle initialStyle,
    String? initialLayoutMode,
  })  : _book = book,
        _style = initialStyle,
        _layoutMode = _normalizeLayout(initialLayoutMode) {
    final stored = initialProgress?.locator.extras;
    final storedPage = stored == null ? null : stored['pageIndex'];
    if (storedPage is num && storedPage > 0) {
      _pageIndex = storedPage.toInt();
    }
    final storedDirection = stored == null ? null : stored['direction'];
    if (storedDirection == ReaderDirection.rtl.name) {
      _direction = ReaderDirection.rtl;
    }
  }

  final Book _book;
  final ReadingProgress? initialProgress;
  final StreamController<ReaderEvent> _events =
      StreamController<ReaderEvent>.broadcast();

  final List<VoidCallback> _listeners = <VoidCallback>[];
  ReaderStyle _style;
  String _layoutMode;
  ReaderDirection _direction = ReaderDirection.ltr;
  int _pageIndex = 0;
  int _pageCount = 0;
  bool _loading = true;
  String? _errorMessage;
  bool _disposed = false;
  PdfDocument? _document;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  int get pageCount => _pageCount;
  int get pageIndex => _pageIndex;
  PdfDocument? get document => _document;
  String get layoutMode => _layoutMode;
  bool get isScrollMode =>
      _layoutMode == ReaderLayoutMode.scrollContinuous ||
      _layoutMode == ReaderLayoutMode.scrollBoundary;
  bool get isDoublePage => _layoutMode == ReaderLayoutMode.pagedSpread;
  ReaderDirection get direction => _direction;
  bool get isRtl => _direction == ReaderDirection.rtl;

  @override
  Stream<ReaderEvent> get events => _events.stream;

  @override
  Set<ReaderCapability> get capabilities => PdfReaderEngine._capabilities;

  /// 视图监听会话(翻页/模式/方向变化后同步)。
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  @override
  ReaderFeatures get features => const ReaderFeatures(
        textSelection: ReaderTextSelection.none,
        annotationKinds: <ReaderAnnotationKind>{
          ReaderAnnotationKind.pageBookmark,
          ReaderAnnotationKind.pageNote,
        },
        toc: true, // PDF 大纲;无大纲时 UI 退化为页序。
        pageList: true, // PDF 缩略图。
        layout: ReaderLayoutSupport(
          layoutModes: <String>{
            ReaderLayoutMode.pagedSingle,
            ReaderLayoutMode.pagedSpread,
            ReaderLayoutMode.scrollBoundary,
            ReaderLayoutMode.scrollContinuous,
          },
          spreadable: true,
          direction: ReaderDirection.ltr,
          defaultMode: ReaderLayoutMode.pagedSingle,
        ),
        autoPageAvailable: true,
        keyboardTurnAvailable: true,
        volumeTurnAvailable: true,
        brightnessSupported: true,
        keepScreenOnSupported: true,
      );

  @override
  ReaderSettingsOptions get settingsOptions => ReaderSettingsOptions.comic;

  @override
  List<ReaderAuxAction> get auxActions => const <ReaderAuxAction>[
        ReaderAuxAction(
          id: 'bookmarkPage',
          iconKey: 'bookmark',
          labelKey: 'bookmarkPage',
        ),
        ReaderAuxAction(
          id: 'notePage',
          iconKey: 'note_add',
          labelKey: 'notePage',
        ),
      ];

  @override
  ReaderStyle get style => _style;

  @override
  Widget buildView() => PdfReaderView(session: this);

  @override
  Locator? get currentPosition {
    if (_pageCount <= 0) {
      return null;
    }
    final page = _pageIndex.clamp(0, _pageCount - 1);
    return Locator(
      href: 'page$page',
      cfi: null,
      locations: <String, double>{
        'progression': _pageCount <= 1 ? 0 : page / (_pageCount - 1),
      },
      anchor: null,
      text: null,
      extras: <String, Object>{
        'pageIndex': page,
        'pageCount': _pageCount,
        'direction': _direction.name,
      },
    );
  }

  int get currentUnit {
    if (_pageCount <= 0) {
      return 0;
    }
    return isDoublePage ? _spreadForPage(_pageIndex) : _pageIndex;
  }

  /// 可视格总数(单页=页数;双页=幅数)。
  int get unitCount {
    if (_pageCount <= 1) {
      return _pageCount;
    }
    return isDoublePage ? _spreadCount(_pageCount) : _pageCount;
  }

  /// 可视格 [unit] 的起始页(0-based 页索引)。单页即 unit 本身;
  /// 双页下首页独占一幅,[1,2] [3,4] …。
  int pageIndexForUnit(int unit) {
    if (_pageCount <= 0) {
      return 0;
    }
    final clamped = unit.clamp(0, unitCount - 1);
    return isDoublePage ? _pageForSpread(clamped) : clamped;
  }

  @override
  Future<void> open() async {
    _loading = true;
    _errorMessage = null;
    _notify();
    PdfDocument? document;
    try {
      // pdfrx 原生初始化(幂等);在首次真正开 PDF 前确保 native 库就绪。
      pdfrxFlutterInitialize();
      document = await PdfDocument.openFile(_originalPath());
      _pageCount = document.pages.length;
      if (_pageCount <= 0) {
        throw StateError('PDF has no pages');
      }
      _document = document;
      document = null;
      _pageIndex = _restorePageIndex().clamp(0, _pageCount - 1);
      _loading = false;
      _notify();
      if (_disposed || _events.isClosed) {
        return;
      }
      _events.add(
        ReaderEvent(
          type: ReaderEventType.ready,
          payload: <String, dynamic>{
            'format': 'pdf',
            'bookUid': _book.uid,
            'pageCount': _pageCount,
          },
        ),
      );
      await _emitRelocated();
    } catch (error) {
      await document?.dispose();
      _document = null;
      _loading = false;
      _errorMessage = error.toString();
      _notify();
      if (!_disposed && !_events.isClosed) {
        _events.add(
          ReaderEvent(
            type: ReaderEventType.error,
            message: error.toString(),
          ),
        );
      }
    }
  }

  String _originalPath() {
    final rel = _book.originalRelPath;
    if (rel != null && rel.isNotEmpty) {
      return p.join(_book.rootDir, rel);
    }
    final originalDir = p.join(_book.rootDir, 'original');
    final candidates = <String>[
      ..._listFiles(originalDir),
      ..._listFiles(_book.rootDir),
    ];
    for (final candidate in candidates) {
      if (candidate.toLowerCase().endsWith('.pdf')) {
        return candidate;
      }
    }
    throw StateError('No PDF original found for book ${_book.uid}');
  }

  List<String> _listFiles(String directory) {
    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) {
        return const <String>[];
      }
      return dir
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .toList(growable: false);
    } on FileSystemException {
      return const <String>[];
    }
  }

  /// PDF 大纲(目录)。失败/为空返回空表,调用方退化为页序。
  Future<List<PdfOutlineNode>> loadOutline() async {
    final document = _document;
    if (document == null) {
      return const <PdfOutlineNode>[];
    }
    try {
      return await document.loadOutline();
    } catch (_) {
      return const <PdfOutlineNode>[];
    }
  }

  /// 渲染一页为 Flutter 图像,供缩略图/封面用;失败返回 null。
  /// [targetWidth] 限制渲染宽度(缩略图给小的,封面给适中)。
  Future<ui.Image?> renderPageImage(int pageNumber, {int? targetWidth}) async {
    final document = _document;
    if (document == null || pageNumber < 1 || pageNumber > _pageCount) {
      return null;
    }
    try {
      final page = document.pages[pageNumber - 1];
      final scale = targetWidth == null ? 1.0 : targetWidth / page.width;
      final image = await page.render(
        width: (page.width * scale).round(),
        height: (page.height * scale).round(),
      );
      if (image == null) {
        return null;
      }
      return await image.createImage();
    } catch (_) {
      return null;
    }
  }

  int _restorePageIndex() {
    final stored = initialProgress?.locator.extras;
    final storedPage = stored == null ? null : stored['pageIndex'];
    if (storedPage is num && storedPage > 0) {
      return storedPage.toInt();
    }
    final locations = initialProgress?.locator.locations;
    final progression = locations == null ? null : locations['progression'];
    if (progression is num) {
      return (progression.toDouble() * (_pageCount - 1)).round().clamp(
            0,
            _pageCount - 1,
          );
    }
    return 0;
  }

  @override
  Future<void> navigateNext() async {
    await _moveUnit(currentUnit + 1);
  }

  @override
  Future<void> navigatePrev() async {
    await _moveUnit(currentUnit - 1);
  }

  Future<void> _moveUnit(int unit) async {
    if (_pageCount <= 0) {
      return;
    }
    final clamped = unit.clamp(0, unitCount - 1);
    final page = isDoublePage ? _pageForSpread(clamped) : clamped;
    await _moveToPage(page);
  }

  /// 视图落到可视 [unit] 时同步会话。
  Future<void> setPageFromUnit(int unit) async {
    if (_pageCount <= 0) {
      return;
    }
    final page = isDoublePage ? _pageForSpread(unit) : unit;
    await _moveToPage(page);
  }

  Future<void> _moveToPage(int page) async {
    if (_disposed || _pageCount <= 0) {
      return;
    }
    final clamped = page.clamp(0, _pageCount - 1);
    if (clamped == _pageIndex) {
      return;
    }
    _pageIndex = clamped;
    _notify();
    await _emitRelocated();
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  Future<void> _emitRelocated() async {
    if (_disposed || _events.isClosed) {
      return;
    }
    final position = currentPosition;
    _events.add(
      ReaderEvent(
        type: ReaderEventType.relocated,
        locator: position,
        payload: <String, dynamic>{
          'progression': position?.locations?['progression'] ?? 0,
          'format': 'pdf',
        },
      ),
    );
  }

  /// LTR <-> RTL 翻转(方向随 relocated 持久化,重开恢复)。
  Future<void> toggleDirection() async {
    await setDirection(isRtl ? ReaderDirection.ltr : ReaderDirection.rtl);
  }

  Future<void> setDirection(ReaderDirection direction) async {
    if (_direction == direction) {
      return;
    }
    _direction = direction;
    _notify();
    await _emitRelocated();
  }

  /// 居中点击 → 宿主切换 chrome。
  void emitCenterTap() {
    if (_disposed || _events.isClosed) {
      return;
    }
    _events.add(
      ReaderEvent.fromRaw(
        type: ReaderEventType.tapIntent,
        payload: <String, dynamic>{'zone': 'center', 'mode': 'reading'},
      ),
    );
  }

  @override
  Future<void> goTo(Locator locator) async {
    final stored = locator.extras;
    final storedPage = stored == null ? null : stored['pageIndex'];
    if (storedPage is num) {
      return _moveToPage(storedPage.toInt());
    }
    final href = locator.href;
    if (href != null && href.isNotEmpty) {
      final match = RegExp(r'^page(\d+)$').firstMatch(href);
      if (match != null) {
        return _moveToPage(int.parse(match.group(1)!));
      }
    }
    final locations = locator.locations;
    final progression = locations == null ? null : locations['progression'];
    if (progression is num) {
      return _moveToPage((progression.toDouble() * (_pageCount - 1)).round());
    }
  }

  @override
  Future<void> seekToProgression(double progression) async {
    if (_pageCount <= 0) {
      return;
    }
    await _moveToPage(
      (progression.clamp(0, 1) * (_pageCount - 1)).round(),
    );
  }

  @override
  Future<void> setLayoutMode(String layoutMode) async {
    final normalized = _normalizeLayout(layoutMode);
    if (normalized == _layoutMode) {
      return;
    }
    if (normalized == ReaderLayoutMode.pagedSpread && _pageIndex > 0) {
      _pageIndex = _pageForSpread(_spreadForPage(_pageIndex));
    }
    _layoutMode = normalized;
    _notify();
    await _emitRelocated();
  }

  static String _normalizeLayout(String? layoutMode) {
    final normalized = ReaderLayoutMode.normalize(layoutMode);
    if (normalized == ReaderLayoutMode.pagedAuto) {
      return ReaderLayoutMode.pagedSingle;
    }
    return normalized;
  }

  @override
  Future<void> setStyle(ReaderStyle style) async {
    _style = style;
    _notify();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final document = _document;
    _document = null;
    await document?.dispose();
    _listeners.clear();
    await _events.close();
  }

  // ---- 页几何(与漫画引擎同一套语义) ----

  /// 双页视图里,第 [unit] 幅的起始页索引。约定:首页(封面)独占一幅,
  /// 之后每幅两页:[0], [1,2], [3,4] …
  int _pageForSpread(int unit) {
    if (unit <= 0) {
      return 0;
    }
    return 1 + (unit - 1) * 2;
  }

  /// 双页视图里,页 [page] 落在第几幅(0-based)。
  int _spreadForPage(int page) {
    if (page <= 0) {
      return 0;
    }
    return 1 + (page - 1) ~/ 2;
  }

  /// 双页视图的总幅数。
  int _spreadCount(int pageCount) {
    if (pageCount <= 1) {
      return pageCount;
    }
    return 1 + pageCount ~/ 2; // [0], [1,2], [3,4] …
  }
}
