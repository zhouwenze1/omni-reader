# EPUB Renderer Bridge Protocol

## Commands

The EPUB WebView calls the canonical `window.reader` commands only:

```text
init
configure
open
navigate
clearSelection
reset
getSelectionAnchor
applyHighlight
applyHighlights
removeHighlight
updateHighlight
```

The bridge returns the renderer's existing acknowledgement shape. Command
execution failures and renderer failures continue through the existing `error`
event path.

## Canonical Inputs

Initialisation and configuration are separate from opening a chapter:

```js
await window.reader.init({ debug: false })
await window.reader.configure({
  layoutMode: 'paged_single',
  spineManifest: { bookId, baseUrl, items },
  style: {
    theme: 'day',
    pageGap: 24,
    fontSize: 20,
    lineHeight: 1.6,
    paddingV: 16,
    paddingH: 36,
    textIndentEnabled: true,
    textIndentEm: 2,
    textIndentSkipFirstParagraph: false,
  },
})
await window.reader.open({ url, locator })
```

`open` does not carry a spine manifest. Layout mode determines the paging
column behavior; style payloads do not contain `columnCount` or directional
padding fields.

## Migration

| Historical call or field | Canonical replacement |
| --- | --- |
| `setStyle({ style })` | `configure({ style })` |
| `setCustomCss({ css })` | `configure({ customCss })` |
| `open({ url, spineManifest })` | `configure({ spineManifest })`, then `open({ url })` |
| `style.columnCount` | `configure({ layoutMode })` |
| `style.paddingTop/Right/Bottom/Left` | `style.paddingV` and `style.paddingH` |
| `locator.url` | `locator.href` |

The Flutter domain models still read historical fields for stored-data
migration. The EPUB adapter filters them before sending a new renderer
request.

Navigation uses a strict discriminated payload:

```js
{ kind: 'next' }
{ kind: 'prev' }
{ kind: 'progression', value: 0.5 }
{ kind: 'anchor', value: 'epubcfi(/6/2)' }
```

Locator requests and relocated events use `href`, `cfi`, canonical
`locations`, `anchor`, and `text.highlight`. Historical `url`, `extras`,
`xpath`, `rect`, and other probe fields may be read by the Flutter migration
layer but are filtered before a new renderer request is sent.

## Flutter Mapping

The EPUB adapter preserves the public `ReaderSession` API for the rest of the
application. `ReaderStyleMapper` translates the domain's directional padding
into `paddingV = max(top, bottom)` and `paddingH = max(left, right)`. This
keeps the domain settings format stable while keeping the renderer boundary
canonical.

`ReaderEventReceiver` parses and forwards events only. `ReaderPage` owns
debounced progress persistence and flushes pending progress on backgrounding,
book changes, window close, and disposal.

## Legacy Package

`packages/infrastructure/bridge_web` contains historical web bridge models and
is intentionally not connected to the runtime. `engine_epub` is the only
canonical adapter for the embedded renderer.
