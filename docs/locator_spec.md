# Locator 规格（domain 层）

> 补齐于 2026-09-07（此前为空占位）。渲染器侧 CFI/定位细节见 `vue-book-renderer/docs/05-locator-cfi.md`；桥接协议见 `bridge_protocol.md`。

## 1. 模型

`packages/foundation/domain/lib/models/locator.dart` 的 `Locator` 是跨端阅读位置的规范模型，字段全部可空：

| 字段 | 含义 |
| --- | --- |
| `href` | 章节资源路径（如 `chap.xhtml`），通常带 `#锚点` 片段 |
| `url` | 绝对 URL（历史字段，早期形态） |
| `cfi` | EPUB CFI（规范定位串）；渲染器生成，恢复时优先级最高 |
| `locations` | 位置信息字典（如 `{progression: 0.42}`）；进度同步的"内容指纹"只取 `locator + progression` |
| `anchor` | 元素定位信息（历史/辅助） |
| `text` | 锚定文本片段（标注引用用） |
| `extras` | 扩展字典 |

序列化：`toJson()` 只写出非空字段，保证线上载荷精简且稳定。

## 2. 边界：mapper 规范化

EPUB 边界处 `RendererLocatorMapper`（`packages/engines/epub`）把渲染器回传的定位载荷规范化为上述 canonical 字段，同时保留历史字段读取以兼容旧数据。**渲染器侧只应产出 canonical 载荷；旧形状（如整包 locator 字符串）在 mapper 层消化，不向上泄漏。**

## 3. 进度恢复优先级

打开书恢复进度时按 **cfi > uid/锚点 > progression/href** 逐级回退（`EpubReaderSession` 恢复逻辑）：

1. 有 `cfi` → 渲染器精确定位；
2. 无 cfi 有锚点元素（`[data-uid]`）→ 按锚点定位；
3. 只剩 `progression`/`href` → 渲染器按章节 + 进度比例定位。

三者都是可空字段的原因：不同来源的进度（旧版、他端、手动跳转）可能只带其中一部分。渲染器 relocated 事件携带的 `href` 用于书架"继续阅读"展示与 TOC 当前章节高亮（含 `#锚点`，TOC 匹配见 shared_ui `ReaderTocList`：精确锚点命中优先，章节根回退）。

## 4. 进度持久化

- 全量 `ReadingProgress`（含 `Locator`、`updatedAt`、`lastReadAt`）落在书目录 `progress.json`（`ProgressRepositoryImpl`）。
- `library_index.cachedProgress` 存进度比例快照，驱动书架"继续阅读"与排序；由进度保存同步更新。

## 5. 同步语义（衔接）

进度同步的哈希只覆盖 `locator + progression`（不含时间）；冲突用 `updatedAt` 做 LWW（客户端与服务端均按时间戳收敛，见 `docs/specs/2026-09-07-cloud-backup-and-entity-sync-v2.md`）。
