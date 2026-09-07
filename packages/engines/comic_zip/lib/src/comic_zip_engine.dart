import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;
import 'package:reader_parser_core/reader_parser_core.dart';

import 'comic_page_listing.dart';
import 'comic_pager_view.dart';

class ComicZipReaderEngine extends ReaderEngine {
  static const Set<String> _formats = <String>{'comicZip'};

  static const Set<ReaderCapability> _capabilities = <ReaderCapability>{
    ReaderCapability.linearNavigation,
    ReaderCapability.jumpNavigation,
    ReaderCapability.style,
    ReaderCapability.theme,
  };

  @override
  String get id => 'comiczip';

  @override
  String get displayName => 'Comic';

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
    return ComicZipReaderSession(
      book: book,
      initialProgress: initialProgress,
      initialStyle: initialStyle,
      initialLayoutMode: initialLayoutMode,
    );
  }
}

class ComicZipReaderSession extends ReaderSession
    implements ReaderPageIndexSource, ReaderDirectionTogglable {
  ComicZipReaderSession({
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
  int _generation = 0;
  bool _loading = true;
  String? _errorMessage;
  bool _disposed = false;
  List<String> _pages = const <String>[];
  LazyZipResourceSource? _source;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  @override
  int get pageCount => _pageCount;

  int get pageIndex => _pageIndex;
  List<String> get pages => _pages;
  String get layoutMode => _layoutMode;
  bool get isScrollMode =>
      _layoutMode == ReaderLayoutMode.scrollContinuous ||
      _layoutMode == ReaderLayoutMode.scrollBoundary;
  bool get isDoublePage => _layoutMode == ReaderLayoutMode.pagedSpread;

  ReaderDirection get direction => _direction;

  bool get isRtl => _direction == ReaderDirection.rtl;

  /// Current reading position, usable for page-anchored annotations.
  @override
  Locator? get currentPosition {
    if (_pageCount <= 0) {
      return null;
    }
    final page = _pageIndex.clamp(0, _pageCount - 1);
    return Locator(
      href: _pages[page],
      locations: <String, dynamic>{
        'progression': progressionFromPage(
          page,
          _pageCount,
          doublePage: isDoublePage,
        ),
      },
      extras: <String, dynamic>{
        'pageIndex': page,
        'pageCount': _pageCount,
        'direction': _direction.name,
      },
    );
  }

  @override
  String pageTitle(int index) {
    if (index < 0 || index >= _pages.length) {
      return '${index + 1}';
    }
    return p.basenameWithoutExtension(_pages[index]);
  }

  @override
  Future<Uint8List?> loadPageImage(int index) {
    if (index < 0 || index >= _pages.length) {
      return Future<Uint8List?>.value(null);
    }
    return readPageBytes(_pages[index]);
  }

  /// Generation counter bumped on every (re)open, so the view can rebuild
  /// its scroll/pager controllers after a retry.
  int get generation => _generation;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  /// Index of the visual unit (spread/page) currently on screen.
  int get currentUnit {
    if (_pageCount <= 0) {
      return 0;
    }
    return isDoublePage
        ? spreadForPage(_pageIndex.clamp(0, _pageCount - 1))
        : _pageIndex.clamp(0, _pageCount - 1);
  }

  @override
  Stream<ReaderEvent> get events => _events.stream;

  @override
  Set<ReaderCapability> get capabilities => ComicZipReaderEngine._capabilities;

  @override
  ReaderFeatures get features => const ReaderFeatures(
        textSelection: ReaderTextSelection.none,
        annotationKinds: <ReaderAnnotationKind>{
          ReaderAnnotationKind.pageBookmark,
          ReaderAnnotationKind.pageNote,
        },
        pageList: true,
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
  Widget buildView() {
    return ComicPagerView(session: this);
  }

  String _originalPath() {
    final rel = _book.originalRelPath;
    if (rel != null && rel.isNotEmpty) {
      return p.join(_book.rootDir, rel);
    }
    // Original usually lives at <rootDir>/original; scan for a single archive.
    final originalDir = p.join(_book.rootDir, 'original');
    final candidates = <String>[
      ..._listFiles(originalDir),
      ..._listFiles(_book.rootDir),
    ];
    for (final candidate in candidates) {
      final lower = candidate.toLowerCase();
      if (lower.endsWith('.cbz') || lower.endsWith('.zip')) {
        return candidate;
      }
    }
    throw StateError('No CBZ/ZIP original found for book ${_book.uid}');
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

  @override
  Future<void> open() async {
    _generation++;
    _loading = true;
    _errorMessage = null;
    _notify();
    LazyZipResourceSource? source;
    try {
      source = await LazyZipResourceSource.open(_originalPath());
      final allPaths = await source.listPaths();
      final pages = comicPageEntries(allPaths);
      if (pages.isEmpty) {
        throw StateError('No comic pages found in archive');
      }
      await _source?.close();
      _source = source;
      _pages = pages;
      _pageCount = pages.length;
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
            'format': 'comicZip',
            'bookUid': _book.uid,
            'pageCount': _pageCount,
          },
        ),
      );
      await _emitRelocated();
    } catch (error) {
      // 打开/解析失败:回收本次句柄,避免重试时泄漏 zip 文件句柄。
      await source?.close();
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

  int _restorePageIndex() {
    final stored = initialProgress?.locator.extras;
    final storedPage = stored == null ? null : stored['pageIndex'];
    if (storedPage is num && storedPage > 0) {
      return storedPage.toInt();
    }
    final locations = initialProgress?.locator.locations;
    final progression = locations == null ? null : locations['progression'];
    if (progression is num) {
      return pageFromProgression(
        progression.toDouble(),
        _pageCount,
        doublePage: isDoublePage,
      );
    }
    return 0;
  }

  /// Reads raw bytes for one page entry (cached by the zip source).
  Future<Uint8List?> readPageBytes(String path) {
    final source = _source;
    if (source == null) {
      return Future<Uint8List?>.value(null);
    }
    return source.readBytes(path);
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
    final clamped = unit.clamp(0, _unitCount - 1);
    final page = isDoublePage ? pageForSpread(clamped) : clamped;
    await _moveToPage(page);
  }

  int get _unitCount {
    if (_pageCount <= 1) {
      return _pageCount;
    }
    return isDoublePage ? spreadCount(_pageCount) : _pageCount;
  }

  /// Called by the view when the user lands on visual [unit].
  Future<void> setPageFromUnit(int unit) async {
    if (_pageCount <= 0) {
      return;
    }
    final page = isDoublePage ? pageForSpread(unit) : unit;
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

  @override
  Future<void> goTo(Locator locator) async {
    final stored = locator.extras;
    final storedPage = stored == null ? null : stored['pageIndex'];
    if (storedPage is num) {
      return _moveToPage(storedPage.toInt());
    }
    final href = locator.href;
    if (href != null && href.isNotEmpty) {
      final match = _pages.indexOf(href);
      if (match != -1) {
        return _moveToPage(match);
      }
    }
    final locations = locator.locations;
    final progression = locations == null ? null : locations['progression'];
    if (progression is num) {
      return _moveToPage(
        pageFromProgression(
          progression.toDouble(),
          _pageCount,
          doublePage: isDoublePage,
        ),
      );
    }
  }

  @override
  Future<void> seekToProgression(double progression) async {
    if (_pageCount <= 0) {
      return;
    }
    await _moveToPage(
      pageFromProgression(
        progression,
        _pageCount,
        doublePage: isDoublePage,
      ),
    );
  }

  /// Flips reading direction (LTR <-> RTL). Persisted via the next relocated
  /// event so reopening resumes with the same direction.
  Future<void> setDirection(ReaderDirection direction) async {
    if (_direction == direction) {
      return;
    }
    _direction = direction;
    _notify();
    await _emitRelocated();
  }

  @override
  Future<void> toggleDirection() async {
    await setDirection(isRtl ? ReaderDirection.ltr : ReaderDirection.rtl);
  }

  /// Signals a center-tap so the host toggles its chrome. EPUB gets this from
  /// the renderer; the native comic pager emits it itself.
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
  Future<void> setLayoutMode(String layoutMode) async {
    final normalized = _normalizeLayout(layoutMode);
    if (normalized == _layoutMode) {
      return;
    }
    // Re-home onto the spread start so a page that is the right half of a
    // spread does not get displayed alone after switching modes.
    if (normalized == ReaderLayoutMode.pagedSpread && _pageIndex > 0) {
      _pageIndex = pageForSpread(spreadForPage(_pageIndex));
    }
    _layoutMode = normalized;
    _notify();
    await _emitRelocated();
  }

  static String _normalizeLayout(String? layoutMode) {
    final normalized = ReaderLayoutMode.normalize(layoutMode);
    // Paged auto resolves at the page level; comics default to a single page
    // here and let the UI switch to scroll/spread explicitly.
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
    await _source?.close();
    _source = null;
    _listeners.clear();
    await _events.close();
  }

  Future<void> _emitRelocated() async {
    if (_disposed || _pageCount <= 0 || _events.isClosed) {
      return;
    }
    final page = _pageIndex.clamp(0, _pageCount - 1);
    final progression = progressionFromPage(
      page,
      _pageCount,
      doublePage: isDoublePage,
    );
    final locator = Locator(
      href: _pages[page],
      locations: <String, dynamic>{'progression': progression},
      extras: <String, dynamic>{
        'pageIndex': page,
        'pageCount': _pageCount,
        'direction': _direction.name,
      },
    );
    _events.add(
      ReaderEvent(
        type: ReaderEventType.relocated,
        locator: locator,
        payload: <String, dynamic>{
          'progression': progression,
          'totalProgression': progression,
          'pageIndex': page,
          'pageCount': _pageCount,
          'format': 'comicZip',
        },
      ),
    );
  }
}
