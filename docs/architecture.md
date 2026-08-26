# Architecture

## EPUB Runtime

The EPUB path has three boundaries:

1. `EpubReaderSession` owns the stable `ReaderSession` lifecycle and maps the
   current book, style, layout mode, and saved position into renderer inputs.
2. `ReaderBridgeService` owns the WebView command transport. It uses a fixed
   allowlist of canonical renderer commands and a FIFO queue, so bootstrap
   commands and later navigation cannot overtake one another.
3. `ReaderEventReceiver` owns JavaScript handler registration, event decoding,
   and Locator normalization. It does not persist reading progress.

`ReaderPage` is the single progress persistence entry point. Relocated events
update the in-memory `ReadingProgress` and are written through a debounced
queue. The queue is flushed when the app goes to the background and closed
when the page is disposed.

The domain `ReaderStyle` and `Locator` models intentionally retain historical
fields for settings and migration. `RendererStyleMapper` and
`RendererLocatorMapper` form the EPUB-only boundary that emits canonical
renderer payloads without changing the other reader engines.

## Renderer Assets

`packages/engines/epub/assets/renderer` contains the built renderer shell used
by `LocalReaderHttpServer`: `index.html`, `favicon.ico`, and the Vite
`dist/assets` directory. Book fixtures from the renderer's `public` directory
are intentionally excluded because real EPUB content is served by the active
book mount. `tools/sync_renderer.mjs` rebuilds the sibling
`vue-book-renderer`, copies those runtime files, updates the Flutter asset
declarations, and records SHA-256 hashes in `renderer-manifest.json`.
`tools/check_renderer_assets.mjs` validates the index references, hashes, and
asset declarations in CI or before a release.

`packages/infrastructure/bridge_web` is retained as a legacy, unused model
package. It is not part of the EPUB runtime call chain and must not be used as
the source of the renderer protocol.
