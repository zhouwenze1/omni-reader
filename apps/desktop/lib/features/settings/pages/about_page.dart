import 'package:flutter/material.dart';

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
                    Text('OmniBook', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('版本: 1.0.0 (Build dev)'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('检查更新'),
            ),
          ],
        ),
      ),
    );
  }
}
