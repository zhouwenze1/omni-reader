import 'package:flutter/material.dart';

import '../../../utils/formatters.dart';
import '../controller/me_state.dart';

class StatsDetailPage extends StatelessWidget {
  const StatsDetailPage({super.key, required this.state});

  final MeState state;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('总书籍', '${state.totalBooks}'),
      MapEntry('阅读中', '${state.inProgressBooks}'),
      MapEntry('已完成', '${state.completedBooks}'),
      MapEntry('未开始', '${state.notStartedBooks}'),
      MapEntry('平均进度', AppFormatters.percent(state.averageProgress, digits: 1)),
      MapEntry('近 7 天打开', '${state.booksOpenedInLast7Days}'),
      MapEntry('近 7 天导入', '${state.booksImportedInLast7Days}'),
      MapEntry('高亮', '${state.highlightsCount}'),
      MapEntry('笔记', '${state.notesCount}'),
      MapEntry('书签', '${state.bookmarksCount}'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('统计详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: rows.map((row) {
          return Card(
            child: ListTile(
              title: Text(row.key),
              trailing: Text(row.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}
