---
spec_issue_number:
spec_issue_url:
spec_filed_at: 2026-08-31T00:00:00Z
spec_branch: main
spec_plan_mode: inactive
spec_executed: false
spec_worktree_path:
gate_score:
decisions: D1 Go服务端(Ubuntu VPS); D2 只同步阅读进度; D3 退出推送+启动拉取+手动同步; D4 UUID设备ID存Hive; D5 双端设置页配置; D6 服务器代码入库内 tools/sync-server
---

# 阅读进度同步方案(Reading Progress Sync)

- 日期:2026-08-31 · 分支:main · 状态:草案待确认
- 决策记录:Go 服务端部署 Ubuntu VPS(D1);同步范围=仅阅读进度(D2);同步时机=退出推送+启动拉取+手动同步按钮(D3);设备 ID=随机 UUID 存 Hive(D4);配置入口=双端设置页(D5);服务端代码放 omni-reader 仓库 `tools/sync-server/`(D6)
- 明确不做(后续二期):标注/书签同步、阅读设置同步、统计同步、激活码系统(已单列讨论)

## 1. 背景与价值

用户同时使用平板(Android)和电脑(Windows)阅读 EPUB,但进度各自存在本地,换设备后要手动翻到上次位置。本方案交付:自建 Go 同步服务器 + 双端(移动/桌面)进度增量同步,读完平板合上,电脑上打开同一本书直接接上上次进度。bookUid 由文件指纹派生,同一 EPUB 双端导入后 uid 一致,进度天然对齐——这是方案成立的关键前提。

## 2. 现状(已验证,2026-08-31)

| 事实 | 位置 | 影响 |
| --- | --- | --- |
| `ReadingProgress` 已有完整 toJson/fromJson(bookUid/locator/progression/updatedAt/lastReadAt) | `packages/foundation/domain/lib/models/reading_progress.dart` | 序列化零成本,直接复用 |
| 进度存每书一个 `progress.json`(`<libraryRoot>/<bookUid>/progress.json`) | `packages/infrastructure/data/lib/src/repositories/progress_repository_impl.dart:22-48` | 同步按文件粒度操作 |
| `ProgressRepository` 接口仅 getProgress/saveProgress,无"枚举全部进度" | `packages/foundation/domain/lib/ports/repositories/progress_repository.dart` | 推送侧需新增枚举方法 |
| 设置存 Hive box,已有 `settings.cloud.v1`(CloudOptions) | `packages/infrastructure/data/lib/src/repositories/settings_repository_impl.dart` | 同步配置(服务器地址/token/设备ID)挂 CloudOptions 或新增 key |
| bookUid 由文件指纹派生 | `packages/infrastructure/data/lib/src/repositories/import_repository_impl.dart:94 _deriveBookUid` | 双端同书 uid 一致,进度可对齐 |
| 双端共享 `packages/infrastructure/data` 包 | workspace 结构 | 同步服务放 shared 层,双端复用 |
| 项目无任何网络客户端依赖(http/dio 均未装) | 全仓库 | 需新增一个 HTTP 客户端依赖或手写 HttpClient |
| 无设备标识机制 | 全仓库 | 需新增 UUID 生成+持久化 |
| 阅读页已有 `_progressWriteQueue`(280ms 防抖写库) | `apps/mobile/lib/features/reader/pages/reader_page.dart:118-131`(桌面 `apps/desktop/lib/features/reader/pages/reader_page.dart` 同构) | 退出 flush 后触发推送即可 |

## 3. 架构总览

```
┌─────────────┐   HTTPS + Bearer token   ┌──────────────────┐   HTTPS + Bearer token   ┌─────────────┐
│  移动端 App  │ ◄──────────────────────► │ Go 同步服务器      │ ◄──────────────────────► │  桌面端 App  │
│ (drift/Hive) │   POST /api/sync/push    │ (Ubuntu VPS)      │   POST /api/sync/push    │ (drift/Hive) │
│              │   GET  /api/sync/pull    │ SQLite 存储        │   GET  /api/sync/pull    │              │
└─────────────┘                          └──────────────────┘                          └─────────────┘
```

## 4. Go 服务端设计

### 4.1 位置与形态

- 代码放 `omni-reader/tools/sync-server/`(仓库内,与双端同仓提交)
- 单二进制 + SQLite,无框架依赖(标准库 net/http 起步),可用 `modernc.org/sqlite`(纯 Go 免 CGO,交叉编译友好)
- 交叉编译:Windows 上 `GOOS=linux GOARCH=amd64 go build`,产物 scp 到 VPS

### 4.2 API(全部 JSON,除 /health 外均需 Bearer token)

```
GET  /health                          → {"ok": true}
POST /api/sync/push                   → 批量推送本设备进度变更(内容变化才写入)
      请求: {"deviceId": "uuid", "items": [{bookUid, locator, progression, updatedAt, lastReadAt}, ...]}
      响应: {"accepted": N, "changed": M} → accepted 为处理数, changed 为实际变化数
GET  /api/sync/pull?cursor=<整数>&deviceId=<uuid>
      响应: {"items": [...], "cursor": N, "serverTime": <epoch-ms>}
      语义: 返回服务端 seq > cursor 的变更,按 seq 顺序返回
```

旧客户端的 `after` 参数保留兼容,新客户端使用服务端 cursor,不依赖设备时间。

- token 校验:请求头 `Authorization: Bearer <token>`,token 在服务器 `config.json` 中配置(个人单用户,不做多租户)
- `updatedAt` / `lastReadAt` 继续使用 UTC epoch-ms 记录;增量同步使用服务端 cursor,不做客户端时钟校准

### 4.3 数据模型(SQLite)

```sql
CREATE TABLE IF NOT EXISTS progress_sync (
  book_uid     TEXT PRIMARY KEY,        -- 与客户端 bookUid 一致(文件指纹)
  locator      TEXT NOT NULL,           -- JSON 原样存(客户端 Locator.toJson)
  progression  REAL NOT NULL,
  updated_at   INTEGER NOT NULL,        -- epoch ms(UTC)
  last_read_at INTEGER,                 -- epoch ms,可空
  device_id    TEXT NOT NULL,           -- 最后一次写入方
  content_hash TEXT NOT NULL            -- locator + progression 的内容指纹
);
CREATE INDEX IF NOT EXISTS idx_progress_updated ON progress_sync(updated_at);

CREATE TABLE IF NOT EXISTS sync_changes (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  book_uid     TEXT NOT NULL,
  locator      TEXT NOT NULL,
  progression  REAL NOT NULL,
  updated_at   INTEGER NOT NULL,
  last_read_at INTEGER,
  device_id    TEXT NOT NULL,
  content_hash TEXT NOT NULL
);

-- 设备活跃表:每设备 last_seen_at 用于闲置清理
CREATE TABLE IF NOT EXISTS sync_devices (
  device_id    TEXT PRIMARY KEY,
  last_seen_at INTEGER NOT NULL         -- epoch ms(UTC),push/pull 时更新
);
CREATE INDEX IF NOT EXISTS idx_devices_seen ON sync_devices(last_seen_at);
```

- 按 `book_uid` 主键保存当前状态;内容指纹相同时不新增变更,不使用 `updated_at` 判定新旧
- 内容不同时按服务端到达顺序追加 `sync_changes`,后到达者覆盖当前状态
- 服务器不感知设备间冲突(进度是单值,后写赢足够;标注类才需要多值合并,不在本期)
- **设备废弃**:每次 push/pull 更新 `sync_devices.last_seen_at`;服务器启动时及每日定时清理 `last_seen_at < now - deviceInactiveDays` 的设备(默认 180 天,config 可配),被清理设备下次再同步即重新注册

### 4.4 pull 单书过滤

`GET /api/sync/pull` 增加可选 `bookUid` 参数:指定时只返回该书的当前记录(用于打开图书时按需拉取),省略时按 `cursor` 返回变更日志增量。单书拉取不推进全局 cursor,因此即使本地游标已落后也能拿到该书最新进度。

### 4.4 配置与部署

- `config.json`(与二进制同目录):`{"token": "<共享token>", "port": 8080, "db_path": "sync.db"}`
- systemd 单元文件示例(spec 附部署文档):`ExecStart=/opt/sync-server/sync-server`,`Restart=always`
- 防火墙:仅开放 8080(或经 nginx 反代 + HTTPS;本期直接 HTTP + token 即可,个人数据量小)

## 5. 双端 Flutter 集成

### 5.1 新增包/模块

- `packages/infrastructure/sync/`(或挂在 data 包内新增 `lib/src/sync/`)——建议独立小包 `services_sync`,理由:data 包是基础设施聚合,同步服务是独立关注点,与现有 `services_search` 并列
- 内容:
  - `progress_sync_service.dart` — 核心:push/pull/增量游标/冲突合并/失败重试
  - `progress_sync_config.dart` — 服务器地址、token、deviceId、cursor、每书内容哈希、lastSyncAt(存 Hive)
  - `progress_sync_api_client.dart` — HTTP 封装(用 `package:http` 或 Dart `HttpClient`)

### 5.2 设备 ID

- 首启生成随机 UUID v4,存 Hive(`settings.sync.v2` 的 `deviceId` 字段;兼容读取 v1)
- 双端一致方案,无需原生代码;设备 ID 仅用于服务器区分推送来源/调试

### 5.3 同步时机

| 时机 | 动作 | 说明 |
| --- | --- | --- |
| **打开图书时(新增)** | 正常状态先推送本地未同步内容再 pull;首次迁移以服务器为基线 | 打开前 `pull?bookUid=<uid>` 拉该书当前进度,按内容指纹判断是否需要写入;读完退出时由 dispose 推送变化 |
| 阅读页 dispose(进度 flush 后) | push 该书变更 | 双端 reader_page dispose 处接入,只推当前读的这本书 |
| App 启动(书架页加载后) | pull 增量 → 写本地 | 入口:移动端书架页 init/桌面端 library load 后 |
| 设置页"手动同步"按钮 | push + pull 一次 | 双端设置页新增"同步"入口 |
| 失败 | 静默重试,下个触发点自动再试 | 绝不阻塞阅读 |

### 5.4 增量游标与内容指纹

- 本地存服务端 `cursor` 和每本书最近一次已确认的内容哈希
- 哈希只包含 `locator` 与 `progression`,不包含 `updatedAt`、`lastReadAt`
- push 前枚举本地进度并按哈希筛选,只发送变化项
- pull 后所有本地写入完成才保存服务端 cursor;`lastSyncAt` 仅用于展示
- 冲突:同 bookUid 内容不同则按服务端到达顺序胜出,不比较设备时间

### 5.5 书不在本地书架

- pull 到的记录若本地无该书(bookUid 不在 libraryIndex),**静默跳过不落库**,等书导入后下次 pull 自然接上——无需墓碑/删除逻辑(进度同步不需要删除传播)

### 5.6 配置 UI(双端设置页)

- 入口:设置页新增"阅读同步"项
- 内容:服务器地址(TextInput)、token(TextInput, 密码态)、设备 ID(只读展示)、手动同步按钮、上次同步时间、同步状态(成功/失败/未配置)
- 未配置服务器地址时同步自动禁用,App 完全离线可用

## 6. 验收标准(可测,pass/fail)

1. 平板读某书到 42%,退出 → 电脑设置页点"手动同步" → 打开同一本书,进度为 42%(±1 页)
2. 电脑读到 50%,退出 → 平板打开同一本书(不点任何同步),自动拉到 50% 接上上次位置
3. 双端同时改同一本书(先后到达服务器):后到达者覆盖先到达者,不依赖设备时间
4. 服务器 token 错误:push/pull 返回 401,客户端静默失败不崩溃,阅读不受影响
5. 服务器不可达:阅读照常,同步状态显示"上次失败",恢复后自动补同步
6. 本地无某本书时 pull 到该进度:静默跳过,导入书后进度接上
7. 服务器重启:数据持久(文件落盘),重启后 pull 正常
8. push 幂等:同批数据重推两次,结果一致(upsert 后写赢)
9. 打开图书单书 pull:本地游标落后但打开老书时,仍能拉到该书最新进度并应用
10. 设备闲置清理:手动把 `sync_devices.last_seen_at` 改到 180 天前并触发清理任务,该设备记录被删除;设备下次 push 自动重新注册

## 7. 测试计划

| 层 | 内容 | 数量 |
| --- | --- | --- |
| Go 单元测试 | upsert 后写赢、pull after 过滤、token 校验 | +6 |
| Go 集成测试 | push → pull 回读一致、幂等重推、跨设备覆盖 | +4 |
| Flutter 单测 | ProgressSyncService:游标推进、冲突合并、失败重试、书缺失跳过 | +8 |
| Flutter widget 测试 | 设置页同步 UI(配置保存/手动同步/状态显示) | +3 |
| E2E(手动) | 平板↔电脑真实换机流程(验收标准 1-2) | 2 条手工用例 |

## 8. 工作量估算

| 组件 | 工作量 |
| --- | --- |
| Go 服务端(API+存储+配置+systemd 文档) | ~0.5 天 |
| Flutter sync 服务(push/pull/游标/冲突/重试) | ~1 天 |
| 双端接入(reader dispose 推送、启动拉取、设置页 UI) | ~0.5 天 |
| 测试(Go + Flutter) | ~0.5 天 |
| VPS 部署联调 | ~0.5 天 |
| 合计 | ~3 天 |

## 9. 回滚策略

- 服务端:停掉 systemd 服务即断同步,双端回退到纯本地模式(同步失败静默,无行为变化)
- 客户端:同步服务是新增独立模块,关闭配置即禁用;不触碰现有进度读写路径
- 数据安全:服务器同步表可整体删除重建,不影响任何客户端本地进度

## 10. 文件参考

| 文件 | 变更 |
| --- | --- |
| `tools/sync-server/main.go` | 新增:HTTP 服务+SQLite+token |
| `tools/sync-server/config.example.json` | 新增:配置模板 |
| `tools/sync-server/deploy/omni-sync.service` | 新增:systemd 单元 |
| `packages/infrastructure/services_sync/pubspec.yaml` | 新增:同步包 |
| `packages/infrastructure/services_sync/lib/progress_sync_service.dart` | 新增:核心同步逻辑 |
| `packages/foundation/domain/lib/ports/repositories/progress_repository.dart` | 新增 `listProgress()` 枚举方法 |
| `packages/infrastructure/data/lib/src/repositories/progress_repository_impl.dart` | 实现 `listProgress()` |
| `apps/mobile/lib/features/reader/pages/reader_page.dart` dispose | 进度 flush 后 push |
| `apps/desktop/lib/features/reader/pages/reader_page.dart` dispose | 同上 |
| `apps/mobile/lib/features/settings/*` | 新增"阅读同步"设置项 |
| `apps/desktop/lib/features/settings/*` | 同上 |
| `packages/infrastructure/data/lib/src/repositories/settings_repository_impl.dart` | 新增同步配置 key 读写 |

## 11. 明确不做(Out of Scope)

- 标注(高亮/笔记/书签)同步——需多值合并语义,二期
- 阅读设置同步——全局单值,二期
- 阅读统计跨设备汇总——需设备去重,二期
- 激活码/授权系统——已单独讨论,与同步服务器可共部署但不同时开发
- 进度删除传播(服务器不删,客户端不传播删除)

## 12. 关联

- 服务器与激活码系统共用同一 VPS 与进程(二期扩展 license 接口)
