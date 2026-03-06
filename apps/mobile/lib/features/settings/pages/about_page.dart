import 'package:flutter/material.dart';

import '../widgets/update_button.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于软件')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Icon(Icons.menu_book, size: 64),
                    SizedBox(height: 12),
                    Text(
                      'Reader Mobile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('版本: 0.1.0-dev'),
                    SizedBox(height: 8),
                    Text(
                      '基于 Flutter 的本地阅读器移动端，支持书架、导入、阅读中和设置。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            UpdateButton(
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
