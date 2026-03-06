import 'package:flutter/material.dart';

class CategoryManagePage extends StatelessWidget {
  const CategoryManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('当前版本支持按 categoryId 过滤，分类编辑入口后续补充。'),
        ),
      ),
    );
  }
}
