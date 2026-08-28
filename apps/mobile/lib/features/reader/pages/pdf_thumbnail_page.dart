import 'package:flutter/material.dart';

class PdfThumbnailPage extends StatelessWidget {
  const PdfThumbnailPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF 缩略图')),
      body: Center(
        child:
            Text('PDF 缩略图功能待接入\nbookUid=$bookUid', textAlign: TextAlign.center),
      ),
    );
  }
}
