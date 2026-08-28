import 'package:flutter/material.dart';

class ComicReaderPage extends StatelessWidget {
  const ComicReaderPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('漫画阅读')),
      body: Center(
        child:
            Text('漫画阅读增强模式待接入\nbookUid=$bookUid', textAlign: TextAlign.center),
      ),
    );
  }
}
