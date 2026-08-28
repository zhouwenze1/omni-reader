enum BookFormat {
  epub('epub'),
  pdf('pdf'),
  ldf('ldf'),
  comicZip('comicZip'),
  mobi('mobi'),
  unknown('unknown');

  const BookFormat(this.id);

  final String id;

  static BookFormat fromFilePath(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.epub')) {
      return BookFormat.epub;
    }
    if (lower.endsWith('.pdf')) {
      return BookFormat.pdf;
    }
    if (lower.endsWith('.ldf')) {
      return BookFormat.ldf;
    }
    if (lower.endsWith('.cbz') || lower.endsWith('.zip')) {
      return BookFormat.comicZip;
    }
    if (lower.endsWith('.mobi') || lower.endsWith('.azw3')) {
      return BookFormat.mobi;
    }
    return BookFormat.unknown;
  }
}

