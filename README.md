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
