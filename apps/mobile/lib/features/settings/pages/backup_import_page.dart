import 'package:flutter/material.dart';

class BackupImportPage extends StatelessWidget {
  const BackupImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与导入')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('导出本地数据'),
              subtitle: const Text('导出书籍元数据、进度和设置。原始文件仍保留在本地目录。'),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('恢复导入'),
              subtitle: const Text('恢复入口已预留，后续可接 zip 包恢复。'),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
