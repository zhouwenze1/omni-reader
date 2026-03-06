import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';

class CacheManagePage extends ConsumerWidget {
  const CacheManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataModule = ref.watch(dataModuleProvider);
    final cachePath = dataModule.storagePaths.cacheRoot.path;
    final tempPath = dataModule.storagePaths.tempRoot.path;

    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('缓存目录'),
              subtitle: Text(cachePath),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('临时目录'),
              subtitle: Text(tempPath),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('说明'),
              subtitle: Text('当前版本会自动清理导入过程中的临时目录，手动清理入口后续补充。'),
            ),
          ),
        ],
      ),
    );
  }
}
