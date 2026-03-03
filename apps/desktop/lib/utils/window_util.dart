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
    await windowManager.destroy();
  }
}
