# 书库云备份（客户端架构）

> 2026-09-07 补写。对应服务端部署见根目录 `同步服务器部署与使用指南.md`；多用户/冷热分层决策记录见根 `云端功能重新设计方案-征求意见稿.md`；实体数据同步（标注/设置/统计）见 `docs/specs/2026-09-07-cloud-backup-and-entity-sync-v2.md`。

## 1. 冷热分层模型

每本书本地有两处大文件 + 若干小文件：

| 路径 | 内容 | 可否释放 |
| --- | --- | --- |
| `books/<uid>/` | 解析产物（渲染器用 manifest/positions/content 等） | 可释放 |
| `library/<uid>/original/` | 原始 EPUB（云备份上传源、取回重建源） | 可释放 |
| 封面 / `progress.json` / `annotations.jsonl` | 小文件 | **永远保留** |

释放 = 删两处大文件但保留小文件 → 书架条目变"仅云端"（`evictedAt` 非空、`isAvailableLocally == false`）。

## 2. 状态机

`LibraryIndexEntry.cloudStatus`（drift v5，`library_index` 表）：

```
none ──上传成功──▶ synced
 │ ▲                 │
 └──待传──pending────┘   (上传失败/仅Wi-Fi不满足 → pending)
```

- `evictedAt`：非空 = 本地大文件已释放（仅云端）；取回成功 → 置空。
- `pinLocal`：固定本地，自动释放跳过。
- 书架 ☁ 徽标与批量"释放空间 / 固定在本地"（两端选中模式工具栏）都由这三列驱动；删除书 = 本地行 + 云端副本同删。

## 3. 客户端组件（`packages/infrastructure/services_sync`）

- **`BookCloudManager`**：入口。职责：导入后自动备份、手动"立即备份"、释放/取回、自动维护、删除云端副本、合并云端书单。
- 端口：
  - `BookCloudLibraryPort` → drift DAO（findByBookUid/listAll/upsert/setCloudStatus/setEvicted/setPinLocal/deleteIndexEntry）
  - `BookCloudFilesPort` → 本地大文件操作（originalFile/coverFile/evictBookFiles/restoreFromOriginal/createTempOriginalFile）
  - `NetworkStatusPort` → 仅 Wi-Fi 传输判定
- 后端解析 `resolveFilesBackend(config, api)`：配置了 WebDAV 走 `WebDavFilesBackend`（MKCOL/PUT/GET/DELETE + Basic，坚果云兼容），否则走 `ServerFilesBackend`（自建服务器 vault，同服务器同 token）。

## 4. 关键流程

**导入后自动备份** `uploadBookAfterImport`：autoSync 开且传输允许 → 上传原件 → announce（书单+封面）→ `synced`；不允许/失败 → `pending`。

**自动维护** `runAutomaticMaintenance`（书架 initState + 回前台触发）：重试 `pending` 上传 → `applyManifest()` 合并书单 → `autoEvictOldBooks()`（N 天未读 + 已备份 + 未固定 + epub → 释放）。

**取回已释放的书**：`reader_page` 打开时检测 `evictedAt` → `restoreBook`（下载 original → `ImportRepository.restoreBookFromOriginalFile` 重建解析产物）→ 置 `evictedAt=null` → 正常打开。

**删除云端副本** `deleteCloudBook`（书架删除对话框"同时删除云端副本"）：失败会抛错，调用方（桌面 `library_page_actions` / 移动 `library_page`）删本地后弹 SnackBar 提示，不再静默（2026-09-07 起）。

**合并云端书单** `applyManifest`：增量拉取清单（`since: manifestSyncedAt`）；纯云端条目插入为"仅云端"；墓碑 → 本地有完整副本则保留本地仅取消云标记（`none`），纯云端条目删除。

## 5. 服务端对应

- 书单/文件按用户隔离：`book-vault/<userId>/<bookUid>/`（`tools/sync-server/library.go`）。
- 删除传播：`DELETE /api/library/{uid}` → 墓碑 + 删 vault 文件；他端靠 manifest `deleted_at` 收敛。
- 封面/清单走自建服务器；只有大文件存储可插拔（自建 vault 或 WebDAV）。
