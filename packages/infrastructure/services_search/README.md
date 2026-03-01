# services_search

EPUB full-book search feasibility package (MVP).

## Features

- On-demand indexing (builds index when `search` is called for an unindexed book)
- Extract chapter text from EPUB via `epub_pro`
- Paragraph segmentation + substring search
- Search result includes location fields: `spineIndex`, `href`, `paraIndex`, `matchOffset`, `cfi`

## Manual search with your EPUB file path

Edit constants in [example/main.dart](./example/main.dart):

- `kEpubPath`
- `kQuery`
- `kBookId`

Then run:

```bash
dart run example/main.dart
```

## Manual test with your EPUB file path

Edit constants in [test/manual_epub_path_test.dart](./test/manual_epub_path_test.dart):

- `kEpubPath`
- `kQuery`
- `kBookId`

Then run:

```bash
dart test test/manual_epub_path_test.dart -r expanded
```

## Regular tests

```bash
dart test
```
