import 'package:flutter/material.dart';

class ReaderShell extends StatelessWidget {
  const ReaderShell({
    super.key,
    required this.topBar,
    required this.body,
    required this.bottomBar,
    required this.chromeVisible,
    this.floatingActionButton,
  });

  final Widget topBar;
  final Widget body;
  final Widget bottomBar;
  final bool chromeVisible;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
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
