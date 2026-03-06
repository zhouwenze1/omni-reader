import 'package:flutter/material.dart';

class TagManagePage extends StatelessWidget {
  const TagManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('标签模型已在领域层预留，移动端编辑入口后续补充。'),
        ),
      ),
    );
  }
}
