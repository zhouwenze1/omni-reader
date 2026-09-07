# 阅读设置规格（ReaderSettings / ReaderStyle）

> 补齐于 2026-09-07（此前为空占位）。

## 1. 分层

- **domain 层**：`ReaderSettings`（`foundation/domain`）——含 UI 布局模式、`ReaderStyle` 子集与辅助开关，是设置持久化的形态。
- **kernel 层**：`ReaderStyle`（`packages/engines/kernel/lib/src/reader_style.dart`）——渲染外观参数（主题/字号/行高/页边距/缩进等）。
- **边界 mapper**：`RendererStyleMapper`（`packages/engines/epub`）把 `ReaderStyle` 映射为渲染器 canonical 样式载荷；只从该边界产出，不直接拼载荷。

## 2. 字段（ReaderStyle）

`theme`（亮/暗/自定义）、`columnCount`、`pageGap`、`fontSize`、`lineHeight`、`paddingTop/Right/Bottom/Left`、`textIndentEnabled`、`textIndentEm`、`textIndentSkipFirstParagraph`（以及 `ReaderSettings` 中的布局模式 `layoutMode` 等）。历史/兼容字段保留用于设置迁移，**新增字段必须同步 mapper 与渲染器 `PayloadValidation` 两侧**。

## 3. 渲染器契约（衔接 bridge_protocol）

- 样式只能经 `configure({ style })` 增量下推，`setStyle` 命令已废弃；`columnCount` 等不再直接出现在渲染器命令里。
- 渲染器侧样式字段白名单与校验见 `vue-book-renderer/src/bridge/PayloadValidation.ts`；增量补丁缺省字段保持现状，不重置。

## 4. 持久化与迁移

`SettingsRepositoryImpl`（`packages/infrastructure/data`，Hive box）：

| 键 | 内容 |
| --- | --- |
| `settings.app.v1` | App 级设置 |
| `settings.reader.v2` | 当前阅读设置（现行键） |
| `settings.reader.v1` | 旧版阅读设置（迁移源：读到 v2 缺失时自动迁移并回写，含 layoutMode 归一化：旧 `paged_spread` → `pagedAuto`） |
| `settings.cloud.v1` | 云备份/同步设置（serverUrl/token/deviceId/开关等） |

## 5. 同步（衔接）

阅读设置经实体同步 v2 的 `settings` 实体做 per-key LWW 跨设备同步（见 `docs/specs/2026-09-07-cloud-backup-and-entity-sync-v2.md`），本地仍以 `settings.reader.v2` 为源。
