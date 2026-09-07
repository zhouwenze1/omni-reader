# omni-reader docs 索引

monorepo 技术文档。渲染器侧对应文档见 `vue-book-renderer/docs/01..09`。

## 架构与协议

| 文档 | 内容 |
| --- | --- |
| `architecture.md` | EPUB 运行时三边界（EpubReaderSession / ReaderBridgeService / ReaderEventReceiver）、层规则、渲染器资产与同步工具 |
| `bridge_protocol.md` | 渲染器 ↔ Flutter 桥接命令协议：命令白名单、configure 增量补丁、历史命令迁移表 |
| `locator_spec.md` | domain `Locator` 模型、mapper 规范化、进度恢复优先级 |
| `reader_settings_spec.md` | `ReaderStyle` 字段 → 渲染器规范样式载荷映射、设置持久化与迁移 |
| `product_baseline_v1.md` | 产品基线：路由、页面状态、双端导航与组件基线 |

## 数据与发布

| 文档 | 内容 |
| --- | --- |
| `database_schema.md` | drift v5 表结构、文件型存储（progress.json/annotations.jsonl）、迁移约定 |
| `release_process.md` | 版本号约定、渲染器资产重同步、发布清单 |
| `cloud-library-backup.md` | 客户端书库云备份架构（冷热分层、BookCloudManager、状态机、WebDAV） |

## 功能规格

| 文档 | 内容 |
| --- | --- |
| `specs/2026-08-30-reading-stats-center.md` | 阅读统计中心规格（v4 表 + 5 模块 + 周报） |
| `specs/2026-08-31-reading-progress-sync.md` | 阅读进度同步（v1）规格（Go 服务器、游标、内容哈希）——已被 v2 超越，见文内注记 |
| `specs/2026-09-07-cloud-backup-and-entity-sync-v2.md` | 云备份 + 实体同步 v2（标注/设置/统计）规格 |

工作区级文档（`Omni/` 根）：`AGENTS.md`（主文档）、`开发状态与路线图.md`（状态+待做）、部署/方案征求意见稿见根 README 导航。
