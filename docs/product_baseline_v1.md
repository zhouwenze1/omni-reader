# Reader Product Baseline (v1)

## Main Navigation
- Reading Now (`/reading-now`)
- Library (`/library`)
- Me (`/me`)

## Secondary Pages
- App Settings (`/settings/app`)
- Reader Settings (`/settings/reader`)
- Cloud Settings (`/settings/cloud`)
- About (`/settings/about`)
- TOC (`/reader/:uid/toc`)
- Search In Book (`/reader/:uid/search`)

## Routing Graph
- Shell
  - `/reading-now`
  - `/library`
  - `/me`
- Standalone
  - `/reader/:uid`
  - `/reader/:uid/toc`
  - `/reader/:uid/search`
  - `/settings`
  - `/settings/app`
  - `/settings/reader`
  - `/settings/cloud`
  - `/settings/about`

## Unified Page States
Every core page must implement these states:
- Loading
- Empty
- Error
- Normal

Desktop implementation:
- `LoadingView`
- `EmptyView`
- `ErrorView`

## Cross-Platform Adaptation Rules
- Mobile: Bottom Navigation (`NavigationBar`) + Fullscreen pages
- Desktop: Left NavigationRail + Content panel

## Component Baseline
- SettingTile
- ToggleTile
- DropdownTile
- SliderTile
- SettingsGroup

## Notes
- This is the frozen baseline for current milestone.
- Future feature iteration should not break route naming or primary IA hierarchy.
