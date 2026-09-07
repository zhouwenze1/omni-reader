import 'dart:typed_data';

/// Optional capability interface a session can implement to expose a visual
/// page index (comic pages, PDF thumbnails, ...). When a session implements
/// it, the shared reader chrome surfaces a page-list/thumbnail entry.
abstract interface class ReaderPageIndexSource {
  int get pageCount;

  /// Human label for the page (e.g. "12", "p12").
  String pageTitle(int index);

  /// Raw image bytes for the page (decoding/downsampling is up to the UI).
  Future<Uint8List?> loadPageImage(int index);
}
