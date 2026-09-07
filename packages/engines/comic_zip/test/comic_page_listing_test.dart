import 'package:engine_comic_zip/src/comic_page_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comicPageEntries', () {
    test('filters junk and non-images, keeps nested image paths', () {
      final entries = comicPageEntries(<String>[
        'ComicInfo.xml',
        '__MACOSX/._cover.jpg',
        'images/.DS_Store',
        'images/Thumbs.db',
        'images/cover.png',
        'page10.jpg',
        'page2.jpg',
      ]);
      expect(entries, <String>[
        'images/cover.png',
        'page2.jpg',
        'page10.jpg',
      ]);
    });

    test('natural sort: 2 before 10, mixed case stable', () {
      expect(
        comicPageEntries(<String>['p10.JPG', 'p2.jpg', 'P1.jpg', 'p1.jpg']),
        <String>['P1.jpg', 'p1.jpg', 'p2.jpg', 'p10.JPG'],
      );
    });

    test('ignores non-image files and directory entries', () {
      final entries = comicPageEntries(<String>[
        'folder/',
        'readme.txt',
        '001.gif',
        'folder/002.webp',
      ]);
      expect(entries, <String>['001.gif', 'folder/002.webp']);
    });
  });

  group('single-page progression', () {
    test('page <-> progression round trip', () {
      for (var page = 0; page < 4; page++) {
        final progression = progressionFromPage(page, 4);
        expect(pageFromProgression(progression, 4), page);
      }
      expect(progressionFromPage(0, 4), 0);
      expect(progressionFromPage(3, 4), 1);
    });

    test('clamps out of range', () {
      expect(pageFromProgression(-1, 4), 0);
      expect(pageFromProgression(2, 4), 4 - 1);
      expect(pageFromProgression(0.5, 1), 0);
      expect(progressionFromPage(0, 1), 0);
    });
  });

  group('double-page spread progression', () {
    test('spread geometry: [0] [1,2] [3,4]', () {
      expect(spreadCount(5), 3);
      expect(pageForSpread(0), 0);
      expect(pageForSpread(1), 1);
      expect(pageForSpread(2), 3);
      expect(spreadForPage(0), 0);
      expect(spreadForPage(1), 1);
      expect(spreadForPage(2), 1);
      expect(spreadForPage(4), 2);
    });

    test('pages sharing a spread map to one progression', () {
      expect(progressionFromPage(1, 5, doublePage: true), 0.5);
      expect(progressionFromPage(2, 5, doublePage: true), 0.5);
      expect(progressionFromPage(3, 5, doublePage: true), 1);
      expect(progressionFromPage(4, 5, doublePage: true), 1);
      expect(progressionFromPage(0, 5, doublePage: true), 0);
    });

    test('seeking lands on the spread start page', () {
      expect(pageFromProgression(1.0, 5, doublePage: true), 3);
      expect(pageFromProgression(0.5, 5, doublePage: true), 1);
      expect(pageFromProgression(0.0, 5, doublePage: true), 0);
      expect(pageFromProgression(0.99, 5, doublePage: true), 3);
      expect(pageFromProgression(0.34, 5, doublePage: true), 1);
    });

    test('single-page count still yields one spread', () {
      expect(spreadCount(1), 1);
      expect(pageFromProgression(1, 1, doublePage: true), 0);
    });
  });
}
