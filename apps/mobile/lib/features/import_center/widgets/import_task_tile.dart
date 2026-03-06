import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class ImportTaskTile extends StatelessWidget {
  const ImportTaskTile({
    super.key,
    required this.task,
  });

  final ImportTask task;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.status) {
      ImportTaskStatus.success => Colors.green,
      ImportTaskStatus.failed => Colors.redAccent,
      ImportTaskStatus.alreadyImported => Colors.orange,
      ImportTaskStatus.pending => Theme.of(context).colorScheme.primary,
    };

    final label = switch (task.status) {
      ImportTaskStatus.success => '导入成功',
      ImportTaskStatus.failed => '导入失败',
      ImportTaskStatus.alreadyImported => '已存在',
      ImportTaskStatus.pending => '处理中',
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(
            task.status == ImportTaskStatus.failed
                ? Icons.close
                : Icons.file_present_outlined,
          ),
        ),
        title: Text(
          task.filePath.split(RegExp(r'[\\/]')).last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(task.errorMessage?.isNotEmpty == true
            ? '$label · ${task.errorMessage}'
            : label),
      ),
    );
  }
}
