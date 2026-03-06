import 'package:flutter/material.dart';

import '../../../utils/formatters.dart';

class ReaderDebugPage extends StatelessWidget {
  const ReaderDebugPage({
    super.key,
    required this.bookUid,
    required this.bookTitle,
    required this.format,
    required this.progress,
  });

  final String bookUid;
  final String bookTitle;
  final String format;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读器调试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('书籍 ID'),
              subtitle: Text(bookUid),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('标题'),
              subtitle: Text(bookTitle),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('格式'),
              subtitle: Text(format.toUpperCase()),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('当前进度'),
              subtitle: Text(AppFormatters.percent(progress, digits: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
