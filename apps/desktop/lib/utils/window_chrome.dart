import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows 原生窗口样式控制:阅读时移除标题栏(最小化/最大化/关闭按钮),
/// 退出阅读页恢复。直接操作 Win32 窗口样式,不依赖 window_manager(其
/// TitleBarStyle.hidden 在 Windows 上只做 DWM 视觉隐藏,按钮仍在)。
class WindowChrome {
  WindowChrome._();

  /// 标题栏相关样式位:WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX。
  static const int _titleBarBits =
      WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

  static int _findMainWindow() {
    final title = 'Reader Desktop'.toNativeUtf16();
    try {
      return FindWindow(nullptr, title);
    } finally {
      malloc.free(title);
    }
  }

  /// 进入/退出沉浸式阅读:移除/恢复原生窗口标题栏。
  static Future<void> setImmersive(bool immersive) async {
    final hwnd = _findMainWindow();
    if (hwnd == 0) {
      return;
    }
    final style = GetWindowLongPtr(hwnd, GWL_STYLE);
    final next = immersive ? style & ~_titleBarBits : style | _titleBarBits;
    if (next == style) {
      return;
    }
    SetWindowLongPtr(hwnd, GWL_STYLE, next);
    SetWindowPos(
      hwnd,
      0,
      0,
      0,
      0,
      0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED,
    );
  }
}
