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

  static Future<void> forceExit() async {
    // 1) 视觉先行:立刻隐藏窗口,用户视角应用已退出。WebView2 环境清理
    //    (dispose,平台线程上耗时 1-2 秒)由此转入后台静默进行,不再卡界面。
    try {
      await windowManager.hide().timeout(const Duration(milliseconds: 300));
    } catch (_) {
      // 隐藏失败不阻塞退出流程。
    }
    // 2) 后台收尾:等原生销毁完成(WebView2 慢时它自己也慢,但窗口已不可见),
    //    正常完成后立即退出进程。进度为 280ms 防抖持续落盘、统计为 60s 心跳,
    //    确认退出时均已持久(从阅读页内退出最多丢当前 1 分钟统计段)。
    unawaited(
      () async {
        try {
          await windowManager.destroy().timeout(const Duration(seconds: 1));
        } catch (_) {}
        exit(0);
      }(),
    );
    // 3) 兜底:即使 destroy 卡死,进程也一定结束。窗口寿命必须压到秒级:
    //    存活过久的隐藏窗口会被二次启动的单实例逻辑当目标激活,呈现白屏僵尸。
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    exit(0);
  }
}
