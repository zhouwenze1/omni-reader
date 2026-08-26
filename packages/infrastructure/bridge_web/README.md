# Legacy Web Bridge Models

This package is retained for historical data and migration reference only. It
is not used by the EPUB runtime and must not be connected to the current
renderer call chain.

The canonical bridge adapter lives in
`packages/engines/epub/lib/src/runtime`. New renderer calls must use the
canonical `window.reader` commands and payloads documented in
`docs/bridge_protocol.md`.
