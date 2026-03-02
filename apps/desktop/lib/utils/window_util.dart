import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  WindowUtil._();

  static Future<bool> confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('确认退出阅读器？未保存的临时状态可能丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
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
    await windowManager.destroy();
  }
}
