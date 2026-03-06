import 'package:flutter/material.dart';

class AudioPlayerPage extends StatelessWidget {
  const AudioPlayerPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音频播放器')),
      body: Center(
        child: Text('音频增强播放器待接入\nbookUid=$bookUid', textAlign: TextAlign.center),
      ),
    );
  }
}
