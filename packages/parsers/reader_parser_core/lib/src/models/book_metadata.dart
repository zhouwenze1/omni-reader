class BookMetadata {
  const BookMetadata({
    this.identifier,
    this.title,
    this.authors = const <String>[],
    this.language,
    this.publisher,
    this.publicationDate,
    this.description,
    this.subjects = const <String>[],
    this.rights,
    this.coverPath,
    this.extras = const <String, Object?>{},
  });

  final String? identifier;
  final String? title;
  final List<String> authors;
  final String? language;
  final String? publisher;
  final String? publicationDate;
  final String? description;
  final List<String> subjects;
  final String? rights;
  final String? coverPath;
  final Map<String, Object?> extras;

  BookMetadata copyWith({
    String? identifier,
    String? title,
    List<String>? authors,
    String? language,
    String? publisher,
    String? publicationDate,
    String? description,
    List<String>? subjects,
    String? rights,
    String? coverPath,
    Map<String, Object?>? extras,
  }) {
    return BookMetadata(
      identifier: identifier ?? this.identifier,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      publicationDate: publicationDate ?? this.publicationDate,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
      rights: rights ?? this.rights,
      coverPath: coverPath ?? this.coverPath,
      extras: extras ?? this.extras,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'identifier': identifier,
      'title': title,
      'authors': authors,
      'language': language,
      'publisher': publisher,
      'publicationDate': publicationDate,
      'description': description,
      'subjects': subjects,
      'rights': rights,
      'coverPath': coverPath,
      'extras': extras,
    };
  }
}

