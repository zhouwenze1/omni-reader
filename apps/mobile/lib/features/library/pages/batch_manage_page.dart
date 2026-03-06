import 'package:flutter/material.dart';

class BatchManagePage extends StatelessWidget {
  const BatchManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批量管理')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('移动端批量管理入口已预留，建议后续结合多选书架模式一起接入。'),
        ),
      ),
    );
  }
}
