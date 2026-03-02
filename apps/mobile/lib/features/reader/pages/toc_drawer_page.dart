import 'package:flutter/material.dart';

class TocDrawerPage extends StatelessWidget {
  const TocDrawerPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('目录')),
      body: Center(child: Text('目录页开发中\nbookUid=$bookUid', textAlign: TextAlign.center)),
    );
  }
}
