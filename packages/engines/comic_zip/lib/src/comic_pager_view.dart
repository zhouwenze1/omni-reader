import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'comic_page_listing.dart';
import 'comic_zip_engine.dart';

/// Full-bleed comic reading surface hosted by [ComicZipReaderSession.buildView].
///
/// Renders the book in one of three layouts driven by the session's layout
/// mode: vertical scroll, horizontal single page, or horizontal double-page
/// spreads. Interactions:
/// - paged modes: mouse wheel turns pages; tapping the left/right third turns
///   pages (direction-aware), tapping the center toggles the reader chrome.
/// - scroll mode: the wheel scrolls; a tap toggles the chrome.
/// Pinch zoom stays available on touch; desktop mouse-wheel zoom is disabled.
/// Double-tap zoom is intentionally omitted so single taps act immediately —
/// Flutter would otherwise hold every tap ~300ms to disambiguate a double tap.
class ComicPagerView extends StatefulWidget {
  const ComicPagerView({super.key, required this.session});

  final ComicZipReaderSession session;

  @override
  State<ComicPagerView> createState() => _ComicPagerViewState();
}

class _ComicPagerViewState extends State<ComicPagerView> {
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final Widget body;
    if (session.loading) {
      body = const _CenteredHint(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (session.errorMessage != null) {
      body = _CenteredHint(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '打开失败:${session.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => session.open(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (session.pageCount == 0) {
      body = const _CenteredHint(
        child: Text('没有可阅读的页面', style: TextStyle(color: Colors.white70)),
      );
    } else {
      body = _ComicPager(
        key: ValueKey<String>(
          '${session.layoutMode}|${session.pageCount}|${session.generation}'
          '|${session.isRtl}',
        ),
        session: session,
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (!session.loading &&
              session.errorMessage == null &&
              session.pageCount > 1 &&
              !session.isScrollMode)
            Positioned(
              left: 0,
              right: 0,
              top: 18,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${session.pageIndex + 1} / ${session.pageCount}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70),
        child: child,
      ),
    );
  }
}

class _ComicPager extends StatefulWidget {
  const _ComicPager({super.key, required this.session});

  final ComicZipReaderSession session;

  @override
  State<_ComicPager> createState() => _ComicPagerState();
}

class _ComicPagerState extends State<_ComicPager> {
  PageController? _pageController;
  ScrollController? _scrollController;
  double _itemExtent = 0;
  bool _firstSyncPending = true;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session.isScrollMode) {
      _scrollController = ScrollController();
    } else {
      _pageController = PageController(initialPage: session.currentUnit);
    }
    session.addListener(_syncToSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncToSession);
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _syncToSession() {
    final session = widget.session;
    final target = session.currentUnit;
    if (session.isScrollMode) {
      final controller = _scrollController;
      if (controller == null || !controller.hasClients || _itemExtent <= 0) {
        return;
      }
      final targetOffset = target * _itemExtent;
      if ((controller.offset - targetOffset).abs() <= 1) {
        return;
      }
      if (_firstSyncPending) {
        controller.jumpTo(targetOffset);
      } else {
        controller.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      final controller = _pageController;
      if (controller == null || !controller.hasClients) {
        return;
      }
      final current = controller.page?.round();
      if (current == null || current == target) {
        return;
      }
      if (_firstSyncPending) {
        controller.jumpToPage(target);
      } else {
        controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onPageSettled(int unit) {
    _firstSyncPending = false;
    widget.session.setPageFromUnit(unit);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final pinchEnabled = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false, // desktop: wheel is for paging, pinch zoom off for now
    };
    // Page-turn / chrome-tap decision for paged modes. In RTL the earlier page
    // sits on the right, so "forward" maps to the left edge.
    void handleTapUp(double dx, double width) {
      final zone = switch (dx / width) {
        < 1 / 3 => 'left',
        > 2 / 3 => 'right',
        _ => 'center',
      };
      switch (zone) {
        case 'left':
          unawaited(
            session.isRtl ? session.navigateNext() : session.navigatePrev(),
          );
        case 'right':
          unawaited(
            session.isRtl ? session.navigatePrev() : session.navigateNext(),
          );
        default:
          session.emitCenterTap();
      }
    }

    void handleWheel(double scrollDy) {
      unawaited(scrollDy > 0 ? session.navigateNext() : session.navigatePrev());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final viewportWidth = constraints.maxWidth;
        if (session.isScrollMode) {
          _itemExtent = viewportHeight;
          return NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              final unit = (metrics.pixels / viewportHeight)
                  .round()
                  .clamp(0, session.pageCount - 1);
              _onPageSettled(unit);
              return false;
            },
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: session.pageCount,
                itemExtent: viewportHeight,
                itemBuilder: (context, index) {
                  return _ZoomablePage(
                    loadBytes: () =>
                        session.readPageBytes(session.pages[index]),
                    cacheWidth: viewportWidth.round(),
                    onTapUp: (dx, width) => session.emitCenterTap(),
                    onWheel: null,
                    zoomEnabled: pinchEnabled,
                  );
                },
              ),
            ),
          );
        }
        final unitCount = session.isDoublePage
            ? spreadCount(session.pageCount)
            : session.pageCount;
        final rtl = session.isRtl;

        // A spread occupies [first .. last] with the earlier page on the right
        // for RTL. Reads the page decoded into [ImageProvider] (in memory) and
        // hands out the visual cell rect used for width-partition tap zones.
        Widget spreadBody(int first, int last, double width) {
          var pages = List<Widget>.generate(last - first + 1, (i) {
            final index = first + i;
            return Expanded(
              child: _ZoomablePage(
                loadBytes: () => session.readPageBytes(session.pages[index]),
                cacheWidth: (width / (last - first + 1)).round(),
                zoomEnabled: pinchEnabled,
              ),
            );
          });
          if (rtl) {
            pages = pages.reversed.toList(growable: true);
          }
          final children = <Widget>[];
          for (var i = 0; i < pages.length; i++) {
            if (i > 0) {
              children.add(const SizedBox(width: 4));
            }
            children.add(pages[i]);
          }
          return Center(
            child: Row(
              children: children,
              // 双页阅读:整幅(row)命中才按点区判定翻页/呼出;书缝(4px)不再拦截点击。
              // RTL 时首幅在右,阅读序仍是"左=上一幅、右=下一幅",故仅反转子项。
              textDirection: TextDirection.ltr,
            ),
          );
        }

        return PageView.builder(
          controller: _pageController,
          itemCount: unitCount,
          reverse: rtl,
          onPageChanged: _onPageSettled,
          itemBuilder: (context, unit) {
            if (session.isDoublePage) {
              if (unit == 0) {
                // 几何约定:首页(封面)独占一幅,[1,2] [3,4] …
                return spreadBody(0, 0, viewportWidth);
              }
              final first = pageForSpread(unit);
              final last = math.min(first + 1, session.pageCount - 1);
              return spreadBody(first, last, viewportWidth);
            }
            return _ZoomablePage(
              loadBytes: () => session.readPageBytes(session.pages[unit]),
              cacheWidth: viewportWidth.round(),
              onTapUp: handleTapUp,
              onWheel: handleWheel,
              zoomEnabled: pinchEnabled,
            );
          },
        );
      },
    );
  }
}

/// A single comic page: loads bytes from the archive, fits them into its cell
/// and supports pinch + double-tap zoom.
class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    required this.loadBytes,
    required this.cacheWidth,
    this.onTapUp,
    this.onWheel,
    this.zoomEnabled = true,
  });

  final Future<Uint8List?> Function() loadBytes;
  final int cacheWidth;

  /// Optional per-cell tap zone handling (single-page paged mode): called with
  /// the local dx within this cell and the cell's width. Undefined while
  /// zoomed/panning.
  final void Function(double dx, double width)? onTapUp;

  /// Optional raw mouse-wheel handler (paged mode): called with the scroll dy.
  /// When null (scroll mode) the page does not consume the wheel.
  final void Function(double scrollDy)? onWheel;

  /// Whether pinch zoom is available (off on desktop for now).
  final bool zoomEnabled;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  late final Future<Uint8List?> _future = widget.loadBytes();
  final TransformationController _transformation = TransformationController();
  Size _cellSize = Size.zero;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cellSize = constraints.biggest;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        return FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (bytes == null || bytes.isEmpty) {
              return const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white38, size: 40),
              );
            }
            final onTapUp = widget.onTapUp;
            final onWheel = widget.onWheel;
            final image = Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              cacheWidth: (widget.cacheWidth * devicePixelRatio).round(),
              filterQuality: FilterQuality.medium,
            );
            final zoomable = _ZoomableImage(
              transformationController: _transformation,
              zoomEnabled: widget.zoomEnabled,
              image: image,
            );
            // Raw wheel handling: desktop wheel pages in paged mode; disabled
            // when this page should not turn pages (scroll mode).
            Widget child = zoomable;
            if (onWheel != null) {
              child = Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    onWheel(event.scrollDelta.dy);
                  }
                },
                child: child,
              );
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onTapUp == null
                  ? null
                  : (details) =>
                      onTapUp(details.localPosition.dx, _cellSize.width),
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Image with pinch (touch) zoom. Desktop mouse-wheel zoom is intentionally not
/// wired (wheel is used for page turns instead).
class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({
    required this.transformationController,
    required this.zoomEnabled,
    required this.image,
  });

  final TransformationController transformationController;
  final bool zoomEnabled;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      minScale: 1,
      maxScale: 5,
      panEnabled: true,
      scaleEnabled: zoomEnabled,
      child: Center(child: image),
    );
  }
}
