import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kernel/kernel.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_engine.dart';

/// PDF 页式阅读视图:与漫画同款交互(单页/双页/滚动、翻页键/滚轮/居中
/// 点击),页内容由 pdfrx 的 [PdfPageView] 渲染(PDFium,自带缓存与释放)。
class PdfReaderView extends StatefulWidget {
  const PdfReaderView({super.key, required this.session});

  final PdfReaderSession session;

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  PdfReaderSession get session => widget.session;

  PageController? _pageController;
  ScrollController? _scrollController;
  bool _attached = false;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    if (session.isScrollMode) {
      _scrollController = ScrollController();
    } else {
      _pageController = PageController(initialPage: session.currentUnit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _attach();
      }
    });
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _attach() {
    if (_attached || !mounted) {
      return;
    }
    _attached = true;
    _syncToSession(animated: false);
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    final wantScroll = session.isScrollMode;
    final hadScroll = _scrollController != null;
    if (wantScroll != hadScroll) {
      _pageController?.dispose();
      _scrollController?.dispose();
      _pageController = null;
      _scrollController = null;
      if (wantScroll) {
        _scrollController = ScrollController();
      } else {
        _pageController = PageController(
          initialPage:
              session.currentUnit.clamp(0, _lastUnit - 1).toInt(),
        );
      }
      _attached = false;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
      return;
    }
    setState(() {});
    _syncToSession(animated: false);
  }

  int get _lastUnit => math.max(1, session.unitCount);

  /// 把控制器对齐到会话当前可视格(外部跳页/恢复位置时)。
  void _syncToSession({bool animated = false}) {
    if (!_attached || session.pageCount <= 0) {
      return;
    }
    final target = session.currentUnit
        .clamp(0, math.max(0, session.unitCount - 1))
        .toInt();
    final controller = _scrollController;
    if (controller != null) {
      if (!controller.hasClients || _itemExtent <= 0) {
        return;
      }
      final targetOffset = target * _itemExtent;
      if ((controller.offset - targetOffset).abs() > 1) {
        if (animated) {
          controller.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        } else {
          controller.jumpTo(targetOffset);
        }
      }
      return;
    }
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) {
      return;
    }
    final current = pageController.page?.round();
    if (current == null || current != target) {
      if (animated) {
        pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else {
        pageController.jumpToPage(target);
      }
    }
  }

  double _itemExtent = 0;

  void _onPageSettled(int unit) {
    if (!_attached) {
      return;
    }
    final current = session.currentUnit;
    if (current != unit) {
      unawaited(session.setPageFromUnit(unit));
    }
  }

  void handleTapUp(double dx, double width) {
    if (width <= 0) {
      return;
    }
    final zone = dx / width;
    if (zone < 1 / 3) {
      unawaited(session.navigatePrev());
    } else if (zone > 2 / 3) {
      unawaited(session.navigateNext());
    } else {
      session.emitCenterTap();
    }
  }

  // 滚轮翻页(桌面翻页模式);260ms 节流,避免一次滚动连续触发。
  DateTime? _lastWheelTurnAt;

  void handleWheel(double scrollDy) {
    final now = DateTime.now();
    final last = _lastWheelTurnAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 260)) {
      return;
    }
    _lastWheelTurnAt = now;
    final forward = scrollDy > 0;
    unawaited(forward ? session.navigateNext() : session.navigatePrev());
  }

  /// 单页容器:整页触控(左/中/右)可选 + 桌面滚轮翻页(翻页模式)。
  Widget _pagedSurface(Widget page, {required double width, bool wheel = true}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => handleTapUp(details.localPosition.dx, width),
      child: wheel
          ? Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  handleWheel(event.scrollDelta.dy);
                }
              },
              child: page,
            )
          : page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final theme = session.style.theme;
    final bg = resolveReaderBackground(theme);
    final contentBg = resolveReaderContentBackground(theme);
    return ColoredBox(
      color: bg,
      child: _buildBody(session, contentBg),
    );
  }

  Widget _buildBody(PdfReaderSession session, Color contentBg) {
    if (session.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PDF 打开失败\n${session.errorMessage}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => session.open(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (session.pageCount <= 0 || session.document == null) {
      return const Center(child: Text('PDF 为空'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;

        Widget pageFor(int pageNumber) {
          return SizedBox.expand(
            child: PdfPageView(
              document: session.document,
              pageNumber: pageNumber,
              maximumDpi: 220,
              backgroundColor: contentBg,
              decoration: null,
              alignment: Alignment.center,
            ),
          );
        }

        // 滚动模式:每页一屏、纵向列表;滚轮留给列表原生滚动。
        if (session.isScrollMode) {
          _itemExtent = viewportHeight;
          return NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              final unit = (metrics.pixels / viewportHeight)
                  .round()
                  .clamp(0, math.max(0, session.unitCount - 1))
                  .toInt();
              _onPageSettled(unit);
              return false;
            },
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: session.unitCount,
                itemExtent: viewportHeight,
                cacheExtent: viewportHeight * 2,
                itemBuilder: (context, unit) {
                  final pageNumber = session.pageIndexForUnit(unit) + 1;
                  return _pagedSurface(
                    pageFor(pageNumber),
                    width: viewportWidth,
                    wheel: false,
                  );
                },
              ),
            ),
          );
        }

        final unitCount = session.unitCount;
        final rtl = session.isRtl;

        // 一"格"内容:单页或双页连排;整格是一个点击/滚轮面。
        Widget spreadBody(int firstPageIndex, int countInSpread) {
          final children = <Widget>[];
          for (var i = 0; i < countInSpread; i++) {
            if (i > 0) {
              children.add(const SizedBox(width: 4));
            }
            children.add(Expanded(child: pageFor(firstPageIndex + i + 1)));
          }
          return _pagedSurface(
            Center(
              child: Row(children: children, textDirection: TextDirection.ltr),
            ),
            width: viewportWidth,
          );
        }

        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: unitCount,
              reverse: rtl,
              allowImplicitScrolling: true,
              onPageChanged: _onPageSettled,
              itemBuilder: (context, unit) {
                if (session.isDoublePage) {
                  final first = session.pageIndexForUnit(unit);
                  final count =
                      math.min(2, session.pageCount - first);
                  return spreadBody(first, count);
                }
                return _pagedSurface(
                  pageFor(unit + 1),
                  width: viewportWidth,
                );
              },
            ),
            // 页指示(非滚动模式,角标)。
            if (session.pageCount > 1)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${session.pageIndex + 1} / ${session.pageCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
