import 'package:kernel/kernel.dart';
import 'package:engine_audio/engine_audio.dart';
import 'package:engine_epub/engine_epub.dart';
import 'package:engine_ldf/engine_ldf.dart';
import 'package:engine_pdf/engine_pdf.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final engineRegistryProvider = Provider<ReaderEngineRegistry>((ref) {
  return ReaderEngineRegistry([
    EpubReaderEngine(),
    PdfReaderEngine(),
    AudioReaderEngine(),
    LdfReaderEngine(),
  ]);
});
