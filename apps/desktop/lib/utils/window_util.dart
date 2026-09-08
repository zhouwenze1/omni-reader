import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';

class WindowUtil {
  WindowUtil._();

  static Future<bool> confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appTitle),
        content: Text(l10n.confirmExitMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.exit),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> requestExit(BuildContext context) async {
    final confirmed = await confirmExit(context);
    if (confirmed) {
      await forceExit();
    }
  }

  static bool _exitStarted = false;

  /// 退出进程。视觉上先隐藏窗口(用户视角立即退出),随后销毁原生窗口;
  /// 销毁完成后只调用一次 [exit],避免并发 exit 触发 C 运行时崩溃
  /// ("Unknown hard error")。若销毁迟迟不结束(WebView2 慢),兜底超时后
  /// 仍保证进程结束——但兜底与正常路径互斥,绝不同时 exit。
  static Future<void> forceExit() async {
    if (_exitStarted) {
      return;
    }
    _exitStarted = true;
    // 1) 视觉先行:立刻隐藏窗口,用户视角应用已退出。WebView2 环境清理
    //    (dispose,平台线程上耗时 1-2 秒)由此转入后台静默进行,不再卡界面。
    try {
      await windowManager.hide().timeout(const Duration(milliseconds: 300));
    } catch (_) {
      // 隐藏失败不阻塞退出流程。
    }

    var destroyed = false;
    try {
      await windowManager.destroy().timeout(const Duration(seconds: 2));
      destroyed = true;
    } catch (_) {
      destroyed = false;
    }
    if (!destroyed) {
      // destroy 卡死/超时:强制结束,避免隐藏窗口变成二次启动的"白屏僵尸"。
      exit(0);
    }
    // 干净销毁完成:让平台收尾走一帧再退出,避免在原生清理中途强杀导致
    // "Unknown hard error"。只此一处调用 exit(不并发)。
    await Future<void>.delayed(const Duration(milliseconds: 80));
    exit(0);
  }
}
