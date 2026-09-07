# 云备份 + 实体同步 v2 规格

> 2026-09-07。本文档描述 2026-09-07 交付的**实体数据同步 v2**（标注/设置/统计）与云备份，超越 08-31 的进度同步草案范围。v1 进度同步见 `specs/2026-08-31-reading-progress-sync.md`（已执行，被本文档部分超越）。

## 1. 范围与决策

- **进度同步（v1）**：内容哈希去重 + seq 变更日志 + 全局游标增量；2026-09-07 起服务端 `applyItemTx` 按 `updatedAt` LWW（旧时间戳迟到写入跳过），客户端 pull 比较时间戳、本地新则回推。
- **实体同步（v2，新增）**：`annotations`（标注 + 墓碑）、`settings`（阅读设置 per-key）、`stats`（阅读会话并集）。各实体独立游标、独立内容开关（`syncAnnotations/syncSettings/syncStats`，默认开）。
- **云备份（v2 配套）**：书库冷热分层 + 大文件后端可插拔（自建 vault / WebDAV），见 `docs/cloud-library-backup.md`。
- 多用户 token 隔离、设备 180 天闲置清理、管理控制台 /admin、二进制热更新（含崩溃回退）。

## 2. 服务端（`tools/sync-server`）

### 表
- `sync_changes`（v1 进度变更日志）、`progress_sync`（进度当前态）。
- `entity_state` / `entity_changes`（实体同步，v2）：`entity_state` 存每用户每实体每键的当前 payload、`updated_at`、`deleted_at`；`entity_changes` 是 append-only 变更日志。
- `library_index`（服务端书单）+ `book-vault/<userId>/<bookUid>/`（大文件）；`sync_devices`。

### 路由（v2）
```
POST /api/v2/sync/{entity}/push   entity ∈ annotations|settings|stats
GET  /api/v2/sync/{entity}/pull?deviceId=&cursor=
```
- push：逐条内容哈希去重；冲突解决声明为客户端 LWW（服务端盲 upsert 当前态 + 记日志）。
- pull：按实体游标增量返回 `entity_state` 变化。
- 另有 v1：`POST /api/sync/push`、`GET /api/sync/pull`（`?cursor=` 全量增量 / `?bookUid=` 单书 / `?after=` 旧版）。

### 游标语义（2026-09-07 修正）
- 全量增量 cursor = **该用户**的 max seq（不再全局跨用户）。
- `bookUid=` 单书拉取返回**该书在该用户**的 max seq；该游标只对单书有效，不得作为全量增量起点。
- 服务端进度冲突按 `updatedAt` LWW：`item.UpdatedAt <= 当前行` → 跳过（不覆盖不记日志）。

## 3. 客户端（`packages/infrastructure/services_sync`）

- `SyncApiClient`：v1 push/pull；`LibraryApiClient`：书单/manifest/大文件。
- `ProgressSyncService`：打开书前拉单书、退出推该书、`syncAll` 全量。哈希只覆盖内容；冲突按 `updatedAt`。
- `DataSyncService`：实体同步——标注合并（LWW + 墓碑，删除在同时间戳时胜出）、设置 per-key LWW、统计按 `(deviceId, startedAt)` 并集去重；每实体独立开关 + 独立游标。
- `BookCloudManager`：见 `docs/cloud-library-backup.md`。
- 设置页（两端）：云备份区（备份/释放/仅Wi-Fi/自动释放天数）+ 数据同步区（每实体开关、上次同步状态、测试连接）。

## 4. 触发点

- 同步：书架页 initState + 回前台；阅读页打开书（单书拉取）、退出（推送该书）；标注/设置变更即推对应实体。
- 云备份维护：书架 initState + 回前台（重试 pending → 合并书单 → 自动释放）。

## 5. 正确性约束（回归要点）

- 进度/实体哈希去重保证重推幂等；时间戳 LWW 保证慢设备不回滚新数据。
- 游标单调：混用 `bookUid` 与全量模式会丢变更（已在服务端把两者游标分离）。
- 删除 = 墓碑传播；本地有完整副本的书被墓碑命中只取消云标记不删本地。

## 6. 测试

- 服务端 `tools/sync-server/*_test.go`：push/pull 往返、用户隔离、LWW（新旧时间戳）、单书游标、实体墓碑、并发热更新、崩溃计数。
- 客户端 `services_sync/test/`：进度 LWW（远端新/本地新）、实体合并、云备份清单/释放守卫。
