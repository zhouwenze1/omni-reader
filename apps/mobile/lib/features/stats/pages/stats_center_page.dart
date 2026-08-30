import 'package:flutter/material.dart';

import 'package:shared_ui/shared_ui.dart';
import '../../../l10n/l10n.dart';

/// 统计中心页(C3 占位:仅空状态;5 个模块在 C4 实装)。
class StatsCenterPage extends StatelessWidget {
  const StatsCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsCenterTitle)),
      body: EmptyView(
        title: l10n.statsEmptyTitle,
        message: l10n.statsEmptyMessage,
      ),
    );
  }
}
