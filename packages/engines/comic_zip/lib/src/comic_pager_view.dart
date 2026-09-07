import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'comic_page_listing.dart';
import 'comic_zip_engine.dart';

/// Full-bleed comic reading surface hosted by [ComicZipReaderSession.buildView].
///
/// Renders the book in one of three layouts driven by the session's layout
/// mode: vertical scroll, horizontal single page, or horizontal double-page
/// spreads. Every page supports pinch zoom and double-tap zoom toggle.
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
      child: body,
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
                    loadBytes: () => session.readPageBytes(session.pages[index]),
                    cacheWidth: viewportWidth.round(),
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
        return PageView.builder(
          controller: _pageController,
          itemCount: unitCount,
          reverse: rtl,
          onPageChanged: _onPageSettled,
          itemBuilder: (context, unit) {
            if (session.isDoublePage) {
              final first = pageForSpread(unit);
              final second = first + 1;
              var pair = <Widget>[
                Expanded(
                  child: _ZoomablePage(
                    loadBytes: () =>
                        session.readPageBytes(session.pages[first]),
                    cacheWidth: (viewportWidth / 2).round(),
                  ),
                ),
              ];
              if (second < session.pageCount) {
                pair.add(const SizedBox(width: 4));
                pair.add(
                  Expanded(
                    child: _ZoomablePage(
                      loadBytes: () =>
                          session.readPageBytes(session.pages[second]),
                      cacheWidth: (viewportWidth / 2).round(),
                    ),
                  ),
                );
              }
              // RTL reads right-to-left: the earlier page sits on the right.
              if (rtl) {
                pair = pair.reversed.toList(growable: true);
              }
              return Center(child: Row(children: pair));
            }
            return _ZoomablePage(
              loadBytes: () => session.readPageBytes(session.pages[unit]),
              cacheWidth: viewportWidth.round(),
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
  const _ZoomablePage({required this.loadBytes, required this.cacheWidth});

  final Future<Uint8List?> Function() loadBytes;
  final int cacheWidth;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  late final Future<Uint8List?> _future = widget.loadBytes();
  final TransformationController _transformation = TransformationController();
  bool _zoomed = false;
  Size _cellSize = Size.zero;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_cellSize == Size.zero) {
      return;
    }
    if (_zoomed) {
      _transformation.value = Matrix4.identity();
      _zoomed = false;
      return;
    }
    final center = _cellSize.center(Offset.zero);
    const zoom = 2.2;
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, zoom)
      ..setEntry(1, 1, zoom)
      ..setEntry(0, 3, center.dx * (1 - zoom))
      ..setEntry(1, 3, center.dy * (1 - zoom));
    _zoomed = true;
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
            return GestureDetector(
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _transformation,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    cacheWidth:
                        (widget.cacheWidth * devicePixelRatio).round(),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
