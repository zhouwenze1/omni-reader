# 数据库规格（drift，schema v5→v6）

> 补齐于 2026-09-07（此前为空占位）。迁移测试见 `packages/infrastructure/data/test/app_database_migration_test.dart`。

## 1. 总览

SQLite 经 drift 的 `customStatement`/`customSelect` 使用（未用 drift 表对象生成）。代码注释里 "schema v4 (current)" 标题已过时——当前迁移链到 v6（v5 云状态、v6 统计 deviceId）。

## 2. 表结构

### library_index（书架主表，v5 加入云状态列）

```sql
bookUid TEXT PRIMARY KEY,
fingerprint TEXT UNIQUE NOT NULL,      -- 内容指纹(去重导入依据)
format TEXT NOT NULL,                  -- epub / w3caudiobook / pdf …
title TEXT NOT NULL, authorsJson TEXT NOT NULL,
categoryId TEXT NULL, coverRelPath TEXT NULL,
importedAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
lastOpenedAt INTEGER NULL, cachedProgress REAL NULL,
cloudStatus TEXT NOT NULL DEFAULT 'none',  -- none | pending | synced
evictedAt INTEGER NULL,                    -- 非空=本地大文件已释放(仅云端)
pinLocal INTEGER NOT NULL DEFAULT 0        -- 固定本地,自动释放跳过
```

索引：format、categoryId、lastOpenedAt、importedAt、cachedProgress。

### collections / collection_items（书桌/合集，v2）

合集主表 + 多对多关联（外键级联删除）。

### reading_sessions（阅读统计会话，v4 + v6）

```sql
id INTEGER PRIMARY KEY AUTOINCREMENT,
bookUid TEXT NOT NULL, startedAt INTEGER NOT NULL,
endedAt INTEGER NOT NULL, seconds INTEGER NOT NULL,
day TEXT NOT NULL, startHour INTEGER NOT NULL,
deviceId TEXT NOT NULL DEFAULT ''   -- v6 加入:跨设备按(设备,会话)合并统计
```

索引：day、bookUid。由 `ReadingSessionRecorder` 以 ~60s 心跳写一行。

## 3. 文件型存储（不入库）

- **书目录** `library/<bookUid>/`：`progress.json`（阅读进度）、`annotations.jsonl`（标注，追加式）、`original/`（原始 EPUB，云备份大文件）。
- **解析产物** `books/<bookUid>/`：渲染器分页/解析产物（manifest/positions/content 等）。
- 云备份冷热分层：大文件（解析产物 + original）可释放；封面/进度/标注永远保留本地。

## 4. 迁移约定

- 版本判定：`PRAGMA user_version`；迁移逐步 `_upgradeToV2..V6` 执行。
- 加列一律 `_hasColumn`（`PRAGMA table_info`）+ `ALTER TABLE ADD COLUMN` 幂等模式。
- 建表/索引均 `IF NOT EXISTS`；新库直接跑完整建表（含全索引），老库按步骤迁移。
- **新迁移必须补 `app_database_migration_test.dart` 的用例**（从上一版本库迁移并断言新列/新表存在与旧数据保留）。

## 5. 已知债务

- `reading_sessions` 无 `startedAt` 索引，统计查询按 startedAt 范围扫会随数据量变慢（路线图 P3）。
- drift 仅作执行器、SQL 手写，表名/列名拼写错误只在运行期暴露。
