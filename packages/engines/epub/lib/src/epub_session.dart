import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kernel/kernel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'runtime/book_package.dart';
import 'runtime/book_position_index.dart';
import 'runtime/book_storage_service.dart';
import 'runtime/book_uri_mapper.dart';
import 'runtime/local_reader_http_server.dart';
import 'runtime/locator_normalizer.dart';
import 'runtime/reader_bridge_service.dart';
import 'runtime/reader_event_receiver.dart';
import 'runtime/renderer_api_models.dart';
import 'runtime/renderer_locator_mapper.dart';
import 'runtime/renderer_style_mapper.dart';

class EpubReaderSession extends ReaderSession {
  EpubReaderSession({
    required Book book,
    this.initialProgress,
    ReaderStyle initialStyle = ReaderStyle.defaults,
    String initialLayoutMode = ReaderLayoutMode.pagedAuto,
  })  : _book = book,
        _readerStyle = initialStyle,
        _layoutMode = ReaderLayoutMode.normalizeRendererMode(initialLayoutMode),
        _runtimeFuture = _prepareRuntime(book.uid);

  final Book _book;
  final ReadingProgress? initialProgress;

  final StreamController<ReaderEvent> _eventsController =
      StreamController<ReaderEvent>.broadcast();
  final Completer<void> _webViewReady = Completer<void>();
  final Completer<void> _pageLoadStopped = Completer<void>();
  final LocatorNormalizer _locatorNormalizer = const LocatorNormalizer();
  final RendererLocatorMapper _rendererLocatorMapper =
      const RendererLocatorMapper();
  final RendererStyleMapper _rendererStyleMapper = const RendererStyleMapper();

  final Future<_SessionRuntime> _runtimeFuture;

  InAppWebViewController? _controller;
  ReaderBridgeService? _bridge;

  bool _openRequested = false;
  bool _bootstrapped = false;
  Future<void>? _bootstrapInFlight;
  Future<void>? _openInFlight;
  bool _debugInfoPublished = false;
  bool _inAppDevToolsOpened = false;
  String? _appliedRendererStyleSignature;

  String _layoutMode;
  ReaderStyle _readerStyle;

  @override
  Stream<ReaderEvent> get events => _eventsController.stream;

  @override
  Set<ReaderCapability> get capabilities => const <ReaderCapability>{
        ReaderCapability.linearNavigation,
        ReaderCapability.jumpNavigation,
        ReaderCapability.style,
        ReaderCapability.theme,
        ReaderCapability.externalLink,
        ReaderCapability.mediaTap,
        ReaderCapability.selection,
        ReaderCapability.highlights,
        ReaderCapability.toc,
        ReaderCapability.inBookSearch,
      };

  @override
  ReaderStyle get style => _readerStyle;

  @override
  Widget buildView() {
    return FutureBuilder<_SessionRuntime>(
      future: _runtimeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('EPUB runtime bootstrap failed: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final runtime = snapshot.data!;
        return InAppWebView(
          webViewEnvironment: runtime.webViewEnvironment,
          initialUrlRequest: URLRequest(url: WebUri(runtime.rendererUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
            mediaPlaybackRequiresUserGesture: false,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            _bridge = ReaderBridgeService(
              controllerProvider: () => _controller!,
              emitEvent: _emitEvent,
            );
            final receiver = ReaderEventReceiver(
              controller: controller,
              bookUuid: _book.uid,
              locatorNormalizer: _locatorNormalizer,
              uriMapper: runtime.uriMapper,
              emitEvent: (event) => _handleRuntimeEvent(runtime, event),
            );
            receiver.registerAll();

            if (!_webViewReady.isCompleted) {
              _webViewReady.complete();
            }
          },
          onLoadStart: (_, url) {
            _emitEvent(
              ReaderEvent(
                type: ReaderEventType.log,
                payload: <String, dynamic>{
                  'phase': 'webview.onLoadStart',
                  'url': url?.toString(),
                },
              ),
            );
          },
          onLoadStop: (controller, url) async {
            if (!_pageLoadStopped.isCompleted) {
              _pageLoadStopped.complete();
            }
            _emitEvent(
              ReaderEvent(
                type: ReaderEventType.log,
                payload: <String, dynamic>{
                  'phase': 'webview.onLoadStop',
                  'url': url?.toString(),
                },
              ),
            );

            if (runtime.debugConfig.openInAppDevTools &&
                !_inAppDevToolsOpened) {
              _inAppDevToolsOpened = true;
              try {
                await controller.openDevTools();
              } catch (error) {
                _emitEvent(
                  ReaderEvent(
                    type: ReaderEventType.error,
                    payload: <String, dynamic>{
                      'phase': 'debug.openInAppDevTools',
                      'error': '$error',
                    },
                    message: 'Failed to open in-app devtools: $error',
                  ),
                );
              }
            }

            if (_openRequested) {
              await _bootstrapAndOpenIfNeeded(runtime);
            }
          },
          onConsoleMessage: (_, message) {
            _emitEvent(
              ReaderEvent(
                type: ReaderEventType.log,
                payload: <String, dynamic>{
                  'phase': 'webview.console',
                  'message': message.message,
                  'level': message.messageLevel.toString(),
                },
              ),
            );
          },
          onReceivedError: (_, request, error) {
            _emitEvent(
              ReaderEvent(
                type: ReaderEventType.error,
                payload: <String, dynamic>{
                  'phase': 'webview.error',
                  'url': request.url.toString(),
                  'type': error.type.toString(),
                  'description': error.description,
                },
                message: error.description,
              ),
            );
          },
          onReceivedHttpError: (_, request, response) {
            _emitEvent(
              ReaderEvent(
                type: ReaderEventType.error,
                payload: <String, dynamic>{
                  'phase': 'webview.httpError',
                  'url': request.url.toString(),
                  'statusCode': response.statusCode,
                  'reasonPhrase': response.reasonPhrase,
                },
                message:
                    'HTTP ${response.statusCode}: ${response.reasonPhrase}',
              ),
            );
          },
        );
      },
    );
  }

  @override
  Future<void> open() async {
    _openRequested = true;
    final runtime = await _runtimeFuture;

    if (!_debugInfoPublished && runtime.debugConfig.enabled) {
      _debugInfoPublished = true;
      _publishDebugInfo(runtime);
      if (runtime.debugConfig.openExternalBrowser) {
        unawaited(_openExternalBrowser(runtime.rendererDebugUrl));
      }
    }

    await _bootstrapAndOpenIfNeeded(runtime);
  }

  @override
  Future<void> setStyle(ReaderStyle style) async {
    _readerStyle = style;
    final stylePayload = _rendererStyleMapper.toPayload(_readerStyle);
    final styleSignature = jsonEncode(stylePayload);
    if (_bootstrapped && styleSignature == _appliedRendererStyleSignature) {
      return;
    }
    await _waitWebViewReady();
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }

    if (!_bootstrapped) {
      final bootstrap = _bootstrapInFlight;
      if (bootstrap == null) {
        // The value is retained in _readerStyle and will be included by the
        // next bootstrap.
        return;
      }
      await bootstrap;
    }
    if (!_bootstrapped) {
      return;
    }

    // A newer setting may have arrived while bootstrap was in flight.
    final latestPayload = _rendererStyleMapper.toPayload(_readerStyle);
    final latestSignature = jsonEncode(latestPayload);
    if (latestSignature == _appliedRendererStyleSignature) {
      return;
    }
    await bridge.configure(style: latestPayload);
    _appliedRendererStyleSignature = latestSignature;
  }

  @override
  Future<void> setLayoutMode(String layoutMode) async {
    final nextLayoutMode = ReaderLayoutMode.normalizeRendererMode(layoutMode);
    if (_layoutMode == nextLayoutMode) {
      return;
    }
    _layoutMode = nextLayoutMode;
    await _waitWebViewReady();
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }

    if (!_bootstrapped) {
      final bootstrap = _bootstrapInFlight;
      if (bootstrap == null) {
        return;
      }
      await bootstrap;
    }
    if (!_bootstrapped) {
      return;
    }
    await bridge.configure(layoutMode: _layoutMode);
  }

  @override
  Future<void> navigateNext() {
    return _navigate(const RendererNavigatePayload.next());
  }

  @override
  Future<void> navigatePrev() {
    return _navigate(const RendererNavigatePayload.prev());
  }

  @override
  Future<void> goTo(Locator locator) async {
    final runtime = await _runtimeFuture;
    await _waitWebViewReady();
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }

    final normalizedLocator = _locatorNormalizer.normalizeLocator(
      locator,
      uriMapper: runtime.uriMapper,
      bookUuid: _book.uid,
    );
    final normalized = _rendererLocatorMapper.toPayload(
      normalizedLocator,
      uriMapper: runtime.uriMapper,
      bookUuid: _book.uid,
    );

    final cfi = normalized['cfi'] as String?;
    final href = normalized['href'] as String?;

    // cfi 与 href 同时存在:目标可能不在当前章节,而 navigate(anchor) 只在
    // 章内生效——走 open 让渲染器打开章节后按 cfi 落位(解析失败回退章首)。
    if (cfi != null &&
        cfi.isNotEmpty &&
        href != null &&
        href.isNotEmpty) {
      normalized['href'] = runtime.uriMapper.toPublicHref(href);
      final url = runtime.uriMapper.hrefToHttp(href: href);
      await bridge.open(url: url, locator: normalized);
      return;
    }

    if (cfi != null && cfi.isNotEmpty) {
      await bridge.navigate(RendererNavigatePayload.anchor(cfi));
      return;
    }

    if (href != null && href.isNotEmpty) {
      normalized['href'] = runtime.uriMapper.toPublicHref(href);
      final url = runtime.uriMapper.hrefToHttp(href: href);
      await bridge.open(url: url, locator: normalized);
      return;
    }

    final progression = (normalized['locations'] is Map)
        ? (normalized['locations'] as Map)['progression']
        : null;
    if (progression is num) {
      final mappedLocator = runtime.positionIndex
          ?.resolveLocatorForTotalProgression(progression.toDouble());
      if (mappedLocator != null) {
        final mappedNormalized = _locatorNormalizer.normalizeMap(
          mappedLocator.toJson(),
          uriMapper: runtime.uriMapper,
          bookUuid: _book.uid,
        );
        final mappedLocatorPayload = _rendererLocatorMapper.toPayload(
          Locator.fromJson(mappedNormalized),
          uriMapper: runtime.uriMapper,
          bookUuid: _book.uid,
        );
        final mappedHref = mappedLocatorPayload['href'] as String?;
        if (mappedHref != null && mappedHref.isNotEmpty) {
          final url = runtime.uriMapper.hrefToHttp(href: mappedHref);
          await bridge.open(url: url, locator: mappedLocatorPayload);
          return;
        }
      }
      await bridge.navigate(
        RendererNavigatePayload.progression(progression.toDouble()),
      );
      return;
    }

    final fallbackHref = runtime.metadata.firstSpineHref;
    if (fallbackHref == null || fallbackHref.isEmpty) {
      _emitEvent(
        const ReaderEvent(
          type: ReaderEventType.error,
          message: 'goTo failed: no href and no spine item available',
        ),
      );
      return;
    }

    normalized['href'] = runtime.uriMapper.toPublicHref(fallbackHref);
    final url = runtime.uriMapper.hrefToHttp(href: fallbackHref);
    await bridge.open(url: url, locator: normalized);
  }

  static const String _searchHighlightUid = 'search-hit-temp';

  @override
  Future<void> applySearchHighlight({
    required String href,
    required String prefix,
    required String exact,
    required String suffix,
  }) async {
    final runtime = await _runtimeFuture;
    await _waitWebViewReady();
    final bridge = _bridge;
    if (bridge == null || !_bootstrapped) {
      return;
    }

    // 渲染器按打开章节的 scope href 匹配,先走与 goTo 相同的规范化链。
    final normalizedLocator = _locatorNormalizer.normalizeLocator(
      Locator(href: href),
      uriMapper: runtime.uriMapper,
      bookUuid: _book.uid,
    );
    final normalizedHref = _rendererLocatorMapper
        .toPayload(
          normalizedLocator,
          uriMapper: runtime.uriMapper,
          bookUuid: _book.uid,
        )['href'] as String?;
    if (normalizedHref == null || normalizedHref.isEmpty) {
      return;
    }

    // 清掉上一次的临时命中高亮(渲染器返回 not_found 时忽略)。
    await bridge.removeHighlight(
      <String, dynamic>{'uid': _searchHighlightUid},
    );

    await bridge.applyHighlight(<String, dynamic>{
      'uid': _searchHighlightUid,
      'href': normalizedHref,
      'color': '#FFD54F',
      'anchor': <String, dynamic>{
        'text': <String, dynamic>{
          'prefix': prefix,
          'exact': exact,
          'suffix': suffix,
        },
      },
    });
  }

  Future<void> _navigate(RendererNavigatePayload payload) async {
    await _waitWebViewReady();
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }
    await bridge.navigate(payload);
  }

  Future<void> _bootstrapAndOpenIfNeeded(_SessionRuntime runtime) async {
    final inFlight = _openInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _runBootstrapAndOpen(runtime);
    _openInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_openInFlight, future)) {
        _openInFlight = null;
      }
    }
  }

  Future<void> _runBootstrapAndOpen(_SessionRuntime runtime) async {
    await _ensureBootstrapped(runtime);
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }

    final locator = await _resolveStartLocator(runtime);
    final normalizedLocator = _locatorNormalizer.normalizeLocator(
      locator,
      uriMapper: runtime.uriMapper,
      bookUuid: _book.uid,
    );
    final normalized = _rendererLocatorMapper.toPayload(
      normalizedLocator,
      uriMapper: runtime.uriMapper,
      bookUuid: _book.uid,
    );

    final href =
        (normalized['href'] as String?) ?? runtime.metadata.firstSpineHref;
    if (href == null || href.isEmpty) {
      _emitEvent(
        const ReaderEvent(
          type: ReaderEventType.error,
          message: 'open failed: spine is empty',
        ),
      );
      return;
    }

    normalized['href'] = runtime.uriMapper.toPublicHref(href);
    final openUrl = runtime.uriMapper.hrefToHttp(href: href);

    await bridge.open(url: openUrl, locator: normalized);
    _openRequested = false;
  }

  Future<void> _ensureBootstrapped(_SessionRuntime runtime) async {
    if (_bootstrapped) {
      return;
    }

    final inFlight = _bootstrapInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _runBootstrap(runtime);
    _bootstrapInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_bootstrapInFlight, future)) {
        _bootstrapInFlight = null;
      }
    }
  }

  Future<void> _runBootstrap(_SessionRuntime runtime) async {
    await _waitWebViewReady();
    await _waitPageLoadStopped();
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }
    final ready = await bridge.waitUntilReaderAvailable();
    if (!ready) {
      _emitEvent(
        const ReaderEvent(
          type: ReaderEventType.error,
          payload: <String, dynamic>{
            'phase': 'waitUntilReaderAvailable',
            'timeoutSec': 12,
          },
          message: 'window.reader API not available within 12 seconds',
        ),
      );
      return;
    }

    if (!_bootstrapped) {
      await bridge.init(debug: runtime.debugConfig.enabled);
      await bridge.configure(
        layoutMode: _layoutMode,
        spineManifest: _buildSpineManifest(runtime),
        style: _rendererStyleMapper.toPayload(_readerStyle),
      );
      _bootstrapped = true;
      _appliedRendererStyleSignature = jsonEncode(
        _rendererStyleMapper.toPayload(_readerStyle),
      );
    }
  }

  Future<Locator> _resolveStartLocator(_SessionRuntime runtime) async {
    if (initialProgress != null) {
      final normalized = _locatorNormalizer.normalizeLocator(
        initialProgress!.locator,
        uriMapper: runtime.uriMapper,
        bookUuid: _book.uid,
      );
      final href = normalized.href?.trim();
      if ((href == null || href.isEmpty) && runtime.positionIndex != null) {
        return runtime.positionIndex!.resolveLocatorForTotalProgression(
              initialProgress!.progression,
            ) ??
            normalized;
      }
      return normalized;
    }

    final savedLocator = await runtime.bookStorageService.readLastLocator(
      _book.uid,
    );
    if (savedLocator != null && savedLocator.isNotEmpty) {
      return _locatorNormalizer.fromAny(
        savedLocator,
        uriMapper: runtime.uriMapper,
        bookUuid: _book.uid,
      );
    }

    final firstHref = _chooseInitialReadableHref(runtime.metadata);
    return Locator(
      href: firstHref,
      cfi: null,
      locations: const <String, dynamic>{'progression': 0.0},
      anchor: null,
      text: null,
      extras: null,
    );
  }

  Map<String, dynamic> _buildSpineManifest(_SessionRuntime runtime) {
    return <String, dynamic>{
      'bookId': _book.uid,
      'baseUrl': runtime.uriMapper.bookBaseUrl(),
      'items': runtime.metadata.spineItems
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'href': runtime.uriMapper.toPublicHref(item.href),
            },
          )
          .toList(),
    };
  }

  void _publishDebugInfo(_SessionRuntime runtime) {
    _emitEvent(
      ReaderEvent(
        type: ReaderEventType.log,
        payload: <String, dynamic>{
          'phase': 'debug.startup',
          'debugEnabled': true,
          'serverPort': runtime.serverPort,
          'serverOrigin': runtime.serverOrigin,
          'rendererUrl': runtime.rendererUrl,
          'rendererDebugUrl': runtime.rendererDebugUrl,
          'bookBaseUrl': runtime.uriMapper.bookBaseUrl(),
          'contentRoot': runtime.metadata.contentRoot,
          'mountedBookRootPath': runtime.mountedBookRootPath,
          'webViewRemoteDebugPort': runtime.webViewRemoteDebugPort,
          'webViewRemoteDebugJson': runtime.webViewRemoteDebugJsonEndpoint(
            runtime.serverOrigin,
          ),
          'webViewEnvironmentError': runtime.webViewEnvironmentError,
        },
      ),
    );
  }

  Future<void> _openExternalBrowser(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run(
            'cmd',
            <String>[
              '/c',
              'start',
              '',
              url,
            ],
            runInShell: true);
        return;
      }
      if (Platform.isMacOS) {
        await Process.run('open', <String>[url], runInShell: true);
        return;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', <String>[url], runInShell: true);
        return;
      }
    } catch (error) {
      _emitEvent(
        ReaderEvent(
          type: ReaderEventType.error,
          payload: <String, dynamic>{
            'phase': 'debug.openExternalBrowser',
            'url': url,
            'error': '$error',
          },
          message: 'Failed to open external browser: $error',
        ),
      );
    }
  }

  Future<void> _waitWebViewReady() {
    return _webViewReady.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _emitEvent(
          const ReaderEvent(
            type: ReaderEventType.error,
            payload: <String, dynamic>{
              'phase': 'waitWebViewReady',
              'timeoutSec': 15,
            },
            message: 'WebView was not created within 15 seconds',
          ),
        );
        throw StateError('WebView was not created within 15 seconds');
      },
    );
  }

  Future<void> _waitPageLoadStopped() {
    return _pageLoadStopped.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _emitEvent(
          const ReaderEvent(
            type: ReaderEventType.error,
            payload: <String, dynamic>{
              'phase': 'waitPageLoadStopped',
              'timeoutSec': 15,
            },
            message: 'WebView page did not finish load within 15 seconds',
          ),
        );
        throw StateError('WebView page did not finish load within 15 seconds');
      },
    );
  }

  String? _chooseInitialReadableHref(BookPackageMetadata metadata) {
    if (metadata.spineItems.isEmpty) {
      return null;
    }
    if (metadata.spineItems.length == 1) {
      return metadata.spineItems.first.href;
    }

    for (final item in metadata.spineItems) {
      final name = p.basename(item.href).toLowerCase();
      final isCoverLike = name.contains('cover') ||
          name.contains('titlepage') ||
          name.contains('toc');
      if (!isCoverLike) {
        return item.href;
      }
    }
    return metadata.spineItems.first.href;
  }

  void _emitEvent(ReaderEvent event) {
    if (_eventsController.isClosed) {
      return;
    }
    _eventsController.add(event);
  }

  void _handleRuntimeEvent(_SessionRuntime runtime, ReaderEvent event) {
    if (event.type != ReaderEventType.relocated || event.locator == null) {
      _emitEvent(event);
      return;
    }

    final totalProgression = runtime.positionIndex
        ?.resolveTotalProgressionForLocator(event.locator!);
    if (totalProgression == null) {
      _emitEvent(event);
      return;
    }

    final nextPayload = Map<String, dynamic>.from(
      event.payload ?? const <String, dynamic>{},
    )..['totalProgression'] = totalProgression;

    final nextLocations = Map<String, dynamic>.from(
      event.locator!.locations ?? const <String, dynamic>{},
    )..['totalProgression'] = totalProgression;

    _emitEvent(
      ReaderEvent.fromRaw(
        type: event.type,
        payload: nextPayload,
        locator: event.locator!.copyWith(locations: nextLocations),
        message: event.message,
      ),
    );
  }

  static Future<_SessionRuntime> _prepareRuntime(String bookUid) async {
    final appSupportDir = await getApplicationSupportDirectory();
    final baseDir = Directory(p.join(appSupportDir.path, 'full_reader'));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final booksRootPath = p.join(baseDir.path, 'books');
    final bookStorageService = BookStorageService(booksRootPath: booksRootPath);
    await bookStorageService.ensureBooksRoot();

    final metadata = await bookStorageService.readMetadata(bookUid);
    if (metadata == null) {
      throw StateError(
        'Book metadata missing. Re-import EPUB first. bookUid=$bookUid',
      );
    }
    final positionIndex = await BookPositionIndex.load(
      storageService: bookStorageService,
      bookUuid: bookUid,
    );

    final debugConfig = _EpubDebugConfig.resolve();
    final webViewDebugEnvironment = await _createWebViewEnvironment(
      debugConfig: debugConfig,
      baseDir: baseDir,
    );

    await LocalReaderHttpServer.instance.ensureStarted(
      booksRootPath: booksRootPath,
      activeBookUuid: bookUid,
      activeContentRoot: metadata.contentRoot,
      preferredPort: debugConfig.preferredPort,
    );

    final mapper = BookUriMapper(
      host: '127.0.0.1',
      port: LocalReaderHttpServer.instance.port,
      bookUuid: bookUid,
      contentRoot: metadata.contentRoot,
    );

    return _SessionRuntime(
      rendererUrl: '${LocalReaderHttpServer.instance.origin}/render/index.html',
      rendererDebugUrl: LocalReaderHttpServer.instance.rendererDebugUrl ??
          '${LocalReaderHttpServer.instance.origin}/render/index.html',
      serverOrigin: LocalReaderHttpServer.instance.origin,
      serverPort: LocalReaderHttpServer.instance.port,
      mountedBookRootPath: LocalReaderHttpServer.instance.mountedBookRootPath,
      uriMapper: mapper,
      metadata: metadata,
      positionIndex: positionIndex,
      bookStorageService: bookStorageService,
      debugConfig: debugConfig,
      webViewEnvironment: webViewDebugEnvironment.environment,
      webViewRemoteDebugPort: webViewDebugEnvironment.remoteDebugPort,
      webViewEnvironmentError: webViewDebugEnvironment.errorMessage,
    );
  }

  static Future<_WebViewDebugEnvironment> _createWebViewEnvironment({
    required _EpubDebugConfig debugConfig,
    required Directory baseDir,
  }) async {
    if (!Platform.isWindows ||
        !debugConfig.enableRemoteWebViewDebug ||
        debugConfig.remoteWebViewDebugPort == null) {
      return const _WebViewDebugEnvironment.none();
    }

    final remotePort = debugConfig.remoteWebViewDebugPort!;
    final userDataFolder = p.join(baseDir.path, 'webview2_user_data');
    try {
      final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: userDataFolder,
          additionalBrowserArguments:
              '--remote-debugging-port=$remotePort --remote-allow-origins=*',
        ),
      );
      return _WebViewDebugEnvironment(
        environment: environment,
        remoteDebugPort: remotePort,
      );
    } catch (error) {
      return _WebViewDebugEnvironment(
        environment: null,
        remoteDebugPort: null,
        errorMessage: '$error',
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      final runtime = await _runtimeFuture;
      await runtime.webViewEnvironment?.dispose();
    } catch (_) {}
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }
}

class _SessionRuntime {
  const _SessionRuntime({
    required this.rendererUrl,
    required this.rendererDebugUrl,
    required this.serverOrigin,
    required this.serverPort,
    required this.mountedBookRootPath,
    required this.uriMapper,
    required this.metadata,
    required this.positionIndex,
    required this.bookStorageService,
    required this.debugConfig,
    required this.webViewEnvironment,
    required this.webViewRemoteDebugPort,
    required this.webViewEnvironmentError,
  });

  final String rendererUrl;
  final String rendererDebugUrl;
  final String serverOrigin;
  final int serverPort;
  final String? mountedBookRootPath;
  final BookUriMapper uriMapper;
  final BookPackageMetadata metadata;
  final BookPositionIndex? positionIndex;
  final BookStorageService bookStorageService;
  final _EpubDebugConfig debugConfig;
  final WebViewEnvironment? webViewEnvironment;
  final int? webViewRemoteDebugPort;
  final String? webViewEnvironmentError;

  String? webViewRemoteDebugJsonEndpoint(String serverOrigin) {
    final port = webViewRemoteDebugPort;
    if (port == null) {
      return null;
    }
    final isLoopback = serverOrigin.contains('127.0.0.1');
    final host = isLoopback ? '127.0.0.1' : 'localhost';
    return 'http://$host:$port/json';
  }
}

class _EpubDebugConfig {
  const _EpubDebugConfig({
    required this.enabled,
    required this.preferredPort,
    required this.openExternalBrowser,
    required this.openInAppDevTools,
    required this.enableRemoteWebViewDebug,
    required this.remoteWebViewDebugPort,
  });

  final bool enabled;
  final int? preferredPort;
  final bool openExternalBrowser;
  final bool openInAppDevTools;
  final bool enableRemoteWebViewDebug;
  final int? remoteWebViewDebugPort;

  static _EpubDebugConfig resolve() {
    const forceDebug = bool.fromEnvironment(
      'READER_EPUB_DEBUG',
      defaultValue: false,
    );
    const debugPortRaw = String.fromEnvironment(
      'READER_EPUB_DEBUG_PORT',
      // Let the OS choose a free port by default. Some Windows installations
      // reserve the old 2789 range for Hyper-V and reject the bind outright.
      defaultValue: '',
    );
    const fixedPortRaw = String.fromEnvironment(
      'READER_EPUB_PORT',
      defaultValue: '',
    );
    const openExternal = bool.fromEnvironment(
      'READER_EPUB_DEBUG_OPEN_BROWSER',
      defaultValue: false,
    );
    const openInAppDevTools = bool.fromEnvironment(
      'READER_EPUB_DEBUG_OPEN_INAPP_DEVTOOLS',
      defaultValue: false,
    );
    const enableRemoteWebViewDebug = bool.fromEnvironment(
      'READER_EPUB_WEBVIEW_REMOTE_DEBUG',
      defaultValue: true,
    );
    const remoteWebViewDebugPortRaw = String.fromEnvironment(
      'READER_EPUB_WEBVIEW_REMOTE_DEBUG_PORT',
      defaultValue: '9222',
    );

    final enabled = kDebugMode || forceDebug;
    int? preferredPort;
    if (fixedPortRaw.trim().isNotEmpty) {
      preferredPort = int.tryParse(fixedPortRaw.trim());
    } else if (enabled) {
      preferredPort = int.tryParse(debugPortRaw.trim());
    }

    int? remoteDebugPort;
    if (enabled && enableRemoteWebViewDebug) {
      remoteDebugPort = int.tryParse(remoteWebViewDebugPortRaw.trim());
    }

    return _EpubDebugConfig(
      enabled: enabled,
      preferredPort: preferredPort,
      openExternalBrowser: enabled && openExternal,
      openInAppDevTools: enabled && openInAppDevTools,
      enableRemoteWebViewDebug: enabled && enableRemoteWebViewDebug,
      remoteWebViewDebugPort: remoteDebugPort,
    );
  }
}

class _WebViewDebugEnvironment {
  const _WebViewDebugEnvironment({
    required this.environment,
    required this.remoteDebugPort,
    this.errorMessage,
  });

  const _WebViewDebugEnvironment.none()
      : environment = null,
        remoteDebugPort = null,
        errorMessage = null;

  final WebViewEnvironment? environment;
  final int? remoteDebugPort;
  final String? errorMessage;
}
