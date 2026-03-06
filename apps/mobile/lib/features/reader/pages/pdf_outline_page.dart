import 'package:flutter/material.dart';

class PdfOutlinePage extends StatelessWidget {
  const PdfOutlinePage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF 大纲')),
      body: Center(
        child: Text('PDF 大纲功能待接入\nbookUid=$bookUid', textAlign: TextAlign.center),
      ),
    );
  }
}
