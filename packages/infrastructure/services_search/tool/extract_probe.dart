import 'dart:io';
import 'dart:typed_data';
import 'package:services_search/services_search.dart';

Future<void> main() async {
  final bytes = await File(r'C:\Users\Administrator\Desktop\Omni\测试.epub').readAsBytes();
  final chapters = await EpubTextExtractor().readChapters(Uint8List.fromList(bytes));
  var found = 0;
  for (final ch in chapters) {
    for (var i = 0; i < (ch.segments?.length ?? 0); i++) {
      final seg = ch.segments![i];
      final idx = seg.text.indexOf('主人');
      if (idx < 0) continue;
      found++;
      if (found > 3) continue;
      final end = (idx + 2).clamp(0, seg.text.length);
      final pStart = (idx - 16).clamp(0, seg.text.length);
      final sEnd = (end + 16).clamp(0, seg.text.length);
      print('HIT$found: spine=${ch.spineIndex} href=${ch.href} seg=$i offset=$idx segLen=${seg.text.length}');
      print('  PREFIX=[${seg.text.substring(pStart, idx)}]');
      print('  EXACT=[${seg.text.substring(idx, end)}]');
      print('  SUFFIX=[${seg.text.substring(end, sEnd)}]');
      print('  CFIPATH=[${seg.cfiPath}]');
    }
  }
  print('total hits: $found');
}
