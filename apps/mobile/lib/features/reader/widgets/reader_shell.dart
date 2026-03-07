import 'package:flutter/material.dart';

class ReaderShell extends StatelessWidget {
  const ReaderShell({
    super.key,
    required this.topBar,
    required this.body,
    required this.bottomBar,
    required this.chromeVisible,
    required this.backgroundColor,
    this.floatingActionButton,
    this.immersiveOverlay,
    this.immersiveOverlayPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final Widget topBar;
  final Widget body;
  final Widget bottomBar;
  final bool chromeVisible;
  final Color backgroundColor;
  final Widget? floatingActionButton;
  final Widget? immersiveOverlay;
  final EdgeInsets immersiveOverlayPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: body),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: _ChromeSlot(
                visible: chromeVisible,
                hiddenOffset: const Offset(0, -1),
                child: topBar,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ChromeSlot(
              visible: chromeVisible,
              hiddenOffset: const Offset(0, 1),
              child: bottomBar,
            ),
          ),
          if (floatingActionButton != null)
            Positioned(
              right: 12,
              bottom: chromeVisible ? 132 : 16,
              child: _ChromeSlot(
                visible: chromeVisible,
                hiddenOffset: const Offset(0, 0.3),
                child: floatingActionButton!,
              ),
            ),
          if (immersiveOverlay != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: immersiveOverlayPadding,
                child: _ChromeSlot(
                  visible: !chromeVisible,
                  hiddenOffset: const Offset(0, 0.3),
                  child: IgnorePointer(
                    child: immersiveOverlay!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChromeSlot extends StatelessWidget {
  const _ChromeSlot({
    required this.visible,
    required this.hiddenOffset,
    required this.child,
  });

  final bool visible;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : hiddenOffset,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}
