import 'package:flutter/material.dart';

class SearchInBookPage extends StatelessWidget {
  const SearchInBookPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书内搜索')),
      body: Center(
        child: Text('书内搜索开发中\nbookUid=$bookUid', textAlign: TextAlign.center),
      ),
    );
  }
}
