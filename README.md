# Full Reader Workspace

Flutter/Dart monorepo for the reader product, managed with `melos`.

## Structure

- `apps/mobile`: mobile app
- `apps/desktop`: desktop app
- `packages/foundation/*`: core/domain/application layers
- `packages/infrastructure/*`: data/services adapters
- `packages/engines/*`: reader engines and engine API

## Quick Start

```bash
dart pub get
melos bootstrap
```

## Quality Baseline

```bash
dart analyze
```

Current package tests:

```bash
cd packages/infrastructure/services_search
dart test
```

## EPUB Renderer Bridge

The EPUB engine embeds the built `vue-book-renderer` output and calls only the
canonical `window.reader` API. The public renderer commands are:

```text
init, configure, open, navigate, clearSelection, reset,
getSelectionAnchor, applyHighlight, applyHighlights,
removeHighlight, updateHighlight
```

`ReaderSession.setStyle()` and `ReaderSession.setLayoutMode()` remain stable
Flutter abstractions. The EPUB adapter translates them into
`configure({ style })` and `configure({ layoutMode })`; it never calls the
removed `setStyle` or `setCustomCss` renderer commands.

To refresh the embedded renderer from the sibling checkout:

```bash
node tools/sync_renderer.mjs
node tools/check_renderer_assets.mjs
```

Use `RENDERER_PATH` or `--renderer <path>` when the renderer is not located at
`../vue-book-renderer`. The sync command rebuilds the renderer, replaces the
embedded files, updates the EPUB asset list, and writes a hash manifest.
