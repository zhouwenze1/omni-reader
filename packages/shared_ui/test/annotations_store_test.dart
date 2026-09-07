import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';
import 'package:shared_ui/shared_ui.dart';

class _MemoryAnnotationRepository implements AnnotationRepository {
  List<Annotation> values = <Annotation>[];
  int replaceCount = 0;

  @override
  Future<List<Annotation>> listAnnotations(String bookUid) async {
    return List<Annotation>.from(values);
  }

  @override
  Future<void> appendAnnotation(String bookUid, Annotation annotation) async {}

  @override
  Future<void> replaceAnnotations(
    String bookUid,
    List<Annotation> annotations,
  ) async {
    replaceCount += 1;
    values = List<Annotation>.from(annotations);
  }
}

void main() {
  test('serializes highlight create, note, color, and remove', () async {
    final repository = _MemoryAnnotationRepository();
    final store = AnnotationsStore(
      repository: repository,
      bookUid: 'book-1',
    );
    await store.load();

    const selection = ReaderSelectionQuote(
      href: 'Text/chapter.xhtml',
      quote: ReaderTextQuote(prefix: 'a ', exact: 'quote', suffix: ' b'),
    );
    final annotation = await store.createHighlight(
      selection: selection,
      color: AnnotationPalette.defaultColor,
    );
    await store.setNote(annotation.id, 'note');
    await store.changeColor(annotation.id, AnnotationPalette.green);
    expect(store.find(annotation.id)?.note, 'note');
    expect(store.find(annotation.id)?.color, AnnotationPalette.green);

    await store.remove(annotation.id);

    expect(store.items, isEmpty);
    expect(repository.replaceCount, 4);
  });

  test('addPageAnnotation stores bookmark and note with page locator', () async {
    final repository = _MemoryAnnotationRepository();
    final store = AnnotationsStore(
      repository: repository,
      bookUid: 'comic-1',
    );
    await store.load();

    const locator = Locator(
      href: 'page12.jpg',
      locations: <String, dynamic>{'progression': 0.5},
      extras: <String, dynamic>{'pageIndex': 12, 'pageCount': 24},
    );
    final bookmark = await store.addPageAnnotation(
      type: AnnotationType.bookmark,
      locator: locator,
    );
    final note = await store.addPageAnnotation(
      type: AnnotationType.note,
      locator: locator,
      note: '伏笔',
    );

    expect(bookmark.type, AnnotationType.bookmark);
    expect(AnnotationsStore.pageIndexOf(bookmark.locator), 12);
    expect(store.find(note.id)?.note, '伏笔');
    expect(store.readerHighlights, isEmpty,
        reason: '页面书签/笔记不进入 readerHighlights(非文本高亮)');
  });
}
