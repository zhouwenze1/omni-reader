import 'package:flutter/material.dart';

import '../../../utils/formatters.dart';
import 'package:shared_ui/shared_ui.dart';

class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({
    super.key,
    required this.state,
  });

  final MeState state;

  @override
  Widget build(BuildContext context) {
    final averageProgress =
        (state.averageProgress * 100).clamp(0, 100).toStringAsFixed(1);
    final latestOpenedText = state.latestOpenedAt == null
        ? '暂无'
        : AppFormatters.dateTime(state.latestOpenedAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本周概览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(label: '总书籍', value: '${state.totalBooks}'),
                _StatChip(label: '阅读中', value: '${state.inProgressBooks}'),
                _StatChip(label: '已完成', value: '${state.completedBooks}'),
                _StatChip(label: '未开始', value: '${state.notStartedBooks}'),
                _StatChip(label: '平均进度', value: '$averageProgress%'),
                _StatChip(
                    label: '近 7 天打开', value: '${state.booksOpenedInLast7Days}'),
                _StatChip(
                    label: '近 7 天导入',
                    value: '${state.booksImportedInLast7Days}'),
                _StatChip(label: '标注总数', value: '${state.annotationsCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('最近一次打开: $latestOpenedText'),
            const SizedBox(height: 4),
            Text(
              '高亮 ${state.highlightsCount}  路  笔记 ${state.notesCount}  路  书签 ${state.bookmarksCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: '),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
