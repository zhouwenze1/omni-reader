import 'package:flutter/material.dart';

class CloudOptionsPage extends StatelessWidget {
  const CloudOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('云端选项')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text('数据加密'),
              subtitle: Text('移动端暂未接入独立密钥管理，当前沿用本地默认安全策略。'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.data_usage_outlined),
              title: Text('冲突处理'),
              subtitle: Text('默认按最近修改时间覆盖，后续可扩展为手动合并。'),
            ),
          ),
        ],
      ),
    );
  }
}
