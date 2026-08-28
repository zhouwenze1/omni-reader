import 'book_content_document.dart';
import 'book_manifest_document.dart';
import 'book_position_document.dart';

class BookArtifactBundle {
  const BookArtifactBundle({this.manifest, this.positions, this.content});

  final BookManifestDocument? manifest;
  final BookPositionDocument? positions;
  final BookContentDocument? content;

  bool get isEmpty => manifest == null && positions == null && content == null;

  BookArtifactBundle copyWith({
    BookManifestDocument? manifest,
    BookPositionDocument? positions,
    BookContentDocument? content,
  }) {
    return BookArtifactBundle(
      manifest: manifest ?? this.manifest,
      positions: positions ?? this.positions,
      content: content ?? this.content,
    );
  }

  Map<String, Map<String, Object?>> toFileMap() {
    return <String, Map<String, Object?>>{
      if (manifest != null) 'manifest.json': manifest!.toJson(),
      if (positions != null) 'positions.json': positions!.toJson(),
      if (content != null) 'content.json': content!.toJson(),
    };
  }
}
