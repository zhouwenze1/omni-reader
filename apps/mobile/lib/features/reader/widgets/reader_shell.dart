import 'package:flutter/material.dart';

class ReaderShell extends StatelessWidget {
  const ReaderShell({
    super.key,
    required this.appBar,
    required this.body,
    required this.bottomBar,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomBar,
    );
  }
}
