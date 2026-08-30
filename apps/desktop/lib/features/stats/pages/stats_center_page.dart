import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:shared_ui/shared_ui.dart';

/// 统计中心页(C3 占位:仅空状态;模块与宽屏布局在 C4/C5 实装)。
class StatsCenterPage extends StatelessWidget {
  const StatsCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsCenterTitle)),
      body: Center(
        child: EmptyView(
          title: l10n.statsEmptyTitle,
          message: l10n.statsEmptyMessage,
        ),
      ),
    );
  }
}
