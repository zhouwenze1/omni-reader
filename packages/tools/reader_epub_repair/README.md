# reader_epub_repair

独立 Dart 包：**保守式 EPUB 修复 + Sigil 启发的显式标准化**。被 `omni-reader` 的 `engine_epub` 以路径依赖消费（`omni-reader/packages/engines/epub/pubspec.yaml`），不是 melos workspace 成员——改它要在本目录单独跑测试。

版本：0.1.0 · Dart 包（无 Flutter 依赖）。

## 设计原则

- **inspect 只读**：绝不改动输入。
- **repair 保守**：没问题的书输出与输入**逐字节一致**（byte-identical）；只修明确的错误（XML 语法、损坏的 container/OPF、缺 DOCTYPE 等），最优先做字节级外科修复，HTML5 全量重序列化是最后手段。
- **standardize 显式**：Sigil 式标准化（路径/引用重写等），**opt-in、幂等**，不与 repair 混在一起。
- **输出原子写**：先写临时再替换；写新 EPUB，永不改源文件。

## 公开 API

```dart
final repairer = EpubRepairer();

// 1) 检查:只报告,不改文件
EpubInspection inspection = await repairer.inspect('book.epub');

// 2) 修复:输入路径 → 输出路径
EpubRepairResult result = await repairer.repair('book.epub', 'out.epub');

// 3) 显式标准化(可选,幂等)
EpubRepairResult result = await repairer.standardize('book.epub', 'out.epub');
```

核心类型（`lib/src/epub_repair_models.dart`）：

- `EpubIssue` / `EpubIssueSeverity`（info/warning/error/fatal）——逐问题报告，含位置与建议。
- `EpubInspection`——检查汇总（各严重度计数 + 问题清单 + 修改建议 action）。
- `EpubRepairResult`——修复结果（每文件 `EpubEntryChange`：unchanged/repaired/created/moved/skipped）。
- `EpubRepairException`——不可修复的结构性错误。

## 实现结构

- `src/epub_repairer.dart`（主体，~2500 行）：ZIP workspace（安全/原子 IO）、container/OPF 恢复、XHTML lint/修复、navigation 重建、标准化与引用重写。
- `src/xhtml_serializer.dart`：XHTML 序列化（SVG/命名空间谨慎处理）。
- `test/epub_repairer_test.dart`：确定性/幂等/安全回归。

## 安全保证

- ZIP-slip（路径穿越）与重复路径显式拒绝；解压总大小有上限（防解压炸弹）。
- mimetype 最先写入且不压缩（EPUB 规范）。
- 输出原子写；失败不留半成品。
- 集成侧：`engine_epub` 导入流程经 `EpubImportRepairMode.repair|none` 控制是否走修复（`book_import_port_adapter` / `epub_import_service`），取代了旧 `epub_toc_reconciler`。

## 已知债务（见工作区 `开发状态与路线图.md` P3）

- 主体单文件过大待拆分；部分 `catch (_)` 过宽可能把真 bug 降级成 warning；HTML5 全量重序列化路径的保守性需复核；一个测试依赖本机绝对路径（CI 上静默跳过）。

## 测试

```bash
dart test
```

## 与 omni-reader 的联调注意

改本包会直接影响 monorepo 构建（path dep）——在 `omni-reader` 侧跑相关测试前，先在本目录 `dart test` 确保本包自身绿。
