import 'dart:math' as math;

/// Image extensions treated as comic pages.
const Set<String> comicImageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
};

final RegExp _naturalChunks = RegExp(r'\d+|\D+');

bool _isJunkPath(String path) {
  final normalized = path.toLowerCase();
  if (normalized.contains('__macosx')) {
    return true;
  }
  final slash = normalized.lastIndexOf('/');
  final base = slash == -1 ? normalized : normalized.substring(slash + 1);
  if (base.startsWith('.')) {
    return true; // .DS_Store, ._cover.jpg, ...
  }
  return base == 'thumbs.db' || base == 'desktop.ini';
}

/// Natural order comparison: numeric runs compare by value (`2.jpg < 10.jpg`).
int naturalCompare(String a, String b) {
  final aChunks = _naturalChunks
      .allMatches(a)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final bChunks = _naturalChunks
      .allMatches(b)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final shared = math.min(aChunks.length, bChunks.length);
  for (var i = 0; i < shared; i++) {
    final x = aChunks[i];
    final y = bChunks[i];
    final xNum = int.tryParse(x);
    final yNum = int.tryParse(y);
    if (xNum != null && yNum != null) {
      if (xNum != yNum) {
        return xNum.compareTo(yNum);
      }
      if (x.length != y.length) {
        return x.length.compareTo(y.length);
      }
      continue;
    }
    final compared = x.toLowerCase().compareTo(y.toLowerCase());
    if (compared != 0) {
      return compared;
    }
  }
  return aChunks.length.compareTo(bChunks.length);
}

/// Filters an archive path list down to comic pages and orders them.
///
/// Drops directory entries, non-image files, and junk such as
/// `__MACOSX/`, `.DS_Store`, `Thumbs.db` and dotfiles.
List<String> comicPageEntries(Iterable<String> paths) {
  final pages = <String>[];
  for (final raw in paths) {
    final path = raw.replaceAll('\\', '/');
    if (path.endsWith('/')) {
      continue;
    }
    final dot = path.lastIndexOf('.');
    if (dot == -1) {
      continue;
    }
    final extension = path.substring(dot).toLowerCase();
    if (!comicImageExtensions.contains(extension)) {
      continue;
    }
    if (_isJunkPath(path)) {
      continue;
    }
    pages.add(path);
  }
  pages.sort(naturalCompare);
  return pages;
}

/// Number of visual spreads when double-page reading is enabled.
///
/// The first page is always a lone spread; the remaining pages pair up:
/// `[0] [1,2] [3,4] ...`.
int spreadCount(int pageCount) {
  if (pageCount <= 0) {
    return 0;
  }
  if (pageCount == 1) {
    return 1;
  }
  return 1 + (pageCount - 1 + 1) ~/ 2;
}

/// First page index shown by the spread at [spreadOrdinal].
int pageForSpread(int spreadOrdinal) {
  if (spreadOrdinal <= 0) {
    return 0;
  }
  return 1 + (spreadOrdinal - 1) * 2;
}

/// Ordinal of the spread that contains [page] in double-page mode.
int spreadForPage(int page) {
  if (page <= 0) {
    return 0;
  }
  return 1 + (page - 1) ~/ 2;
}

/// Progress (0.0–1.0) of the visual unit containing [page].
///
/// With [doublePage], pages that share a spread map to the same progress so
/// the slider is stable while flipping inside a spread.
double progressionFromPage(
  int page,
  int pageCount, {
  bool doublePage = false,
}) {
  if (pageCount <= 1) {
    return 0;
  }
  final units = doublePage ? spreadCount(pageCount) : pageCount;
  final ordinal = doublePage
      ? spreadForPage(page.clamp(0, pageCount - 1))
      : page.clamp(0, pageCount - 1);
  return ordinal / (units - 1);
}

/// Page shown at [progression]. With [doublePage], lands on the spread start.
int pageFromProgression(
  double progression,
  int pageCount, {
  bool doublePage = false,
}) {
  if (pageCount <= 1) {
    return 0;
  }
  final units = doublePage ? spreadCount(pageCount) : pageCount;
  final clamped = progression.clamp(0.0, 1.0);
  final ordinal = (clamped * (units - 1)).round();
  final page = doublePage ? pageForSpread(ordinal) : ordinal;
  return page.clamp(0, pageCount - 1);
}
