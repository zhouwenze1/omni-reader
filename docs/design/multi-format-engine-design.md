# 多格式统一引擎设计(契约 v2)

> 状态:已批准设计(2026-09-07);本次实施到 **P0(契约 v2 骨架 + 双端 UI 描述驱动)**。
> 本文是后续各格式实现(P1–P5)的唯一依据;改契约前先改本文。

## 1. 背景与现状

- 产品目标是多格式本地阅读器。目前只有 **EPUB**(WebView 渲染内核,全功能)与 **CBZ/ZIP 漫画**(原生 pager,本次新增)可真正阅读;PDF/LDF/音频为 stub 假会话。
- kernel `packages/engines/kernel` 已是统一引擎契约:`ReaderEngine`(格式→引擎+能力)+ `ReaderSession`(生命周期/`buildView`/事件/进度)+ `ReaderCapability`(粗能力枚举)+ `ReaderEngineRegistry`(按 format 查引擎)。双端 `ReaderPage` 共用外壳嵌入 `session.buildView()`。
- 本轮漫画落地已把 chrome 按 `ReaderCapability` 门控(EPUB 声明全量 → 零回归),证明"引擎自描述 + UI 自动适配"方向正确。
- **问题**:`capabilities` 是枚举粗开关,表达不了细粒度(如"漫画可整页书签但不可选词高亮")、布局/方向/设置项/辅助动作均未自述,UI 仍残留按 `book.format` 字符串硬编码与 EPUB 特供形态。

## 2. 原则

1. **不在 ReaderPage 里 `if(format)`**。引擎/会话自描述,UI 只读描述渲染。
2. **EPUB = 全功能参照实现**;所有格式共享一套外壳与数据契约,只在引擎内做差异。
3. **加格式 = 写引擎包 + 声明 features/settingsOptions/auxActions**,ReaderPage 几乎不动。
4. 数据契约(Annotation/Locator/ReadingProgress)已格式无关;差异收敛为 **Locator 形状约定**(见 §5)。

## 3. 契约 v2(kernel,增量)

在现有 `capabilities` 之上,为 `ReaderSession` 增加自描述 getter(全部带默认实现,旧调用零破坏):

### 3.1 `ReaderFeatures features`

```dart
enum ReaderTextSelection { none, text, page, time }  // 能否及以何粒度选
enum ReaderAnnotationKind { textHighlight, pageBookmark, pageNote, timeBookmark }
enum ReaderDirection { ltr, rtl }
class ReaderLayoutSupport {
  final Set<String> layoutModes;   // ReaderLayoutMode 子集
  final bool spreadable;           // 可否双页
  final ReaderDirection direction;
  final String defaultMode;
}
class ReaderFeatures {
  ReaderTextSelection textSelection;
  Set<ReaderAnnotationKind> annotationKinds;
  bool toc, pageList, search, dictionary, translate, readAloud;
  bool externalLink, mediaLightbox;
  ReaderLayoutSupport layout;
}
```

- `textSelection`:none(漫画/纯音频)/text(文字系,选词)/page(页面系,选页)/time(时间系,选时间点)。
- `annotationKinds` 与 `textSelection` 配合决定 UI 露出哪些批注入口(高亮只对 text 有意义;页面系=pageBookmark+pageNote;时间系=timeBookmark)。
- `toc/pageList`:TOC(文字系章节目录)或页列表(漫画缩略图/PDF 缩略页)是**二选一**的"结构化导航",谁声明谁显示对应入口。
- `dictionary/translate/readAloud`:选择工具槽位(文字系=选中词句;详见 §8)。
- 兼容:旧 `capabilities` 枚举保留,UI 逐步迁移到 features,旧枚举由新字段覆盖后移除。

### 3.2 `ReaderSettingsOptions settingsOptions`

声明哪些**设置组**对该格式生效,UI 设置面板/对话框按此折叠:

```dart
class ReaderSettingsOptions {
  bool textTypography;   // 字体/字号/行距/缩进(仅文字系)
  bool theme;            // 主题 day/night/sepia(有 chrome 就有)
  bool pageGap;          // 页间距
  bool padding;          // 边距
  bool layoutMode;       // 布局模式选择
  bool playback;         // 音频速度等(时间系)
}
```

EPUB 声明全 `true`;漫画 `textTypography=false`(其余视实现);音频近乎全 `false`(+`playback`)。

### 3.3 `List<ReaderAuxAction> auxActions`

"更多"菜单 / 底栏额外动作由会话声明:

```dart
class ReaderAuxAction {
  final String id;        // 'pdfOutline' | 'pageList' | 'chapterPrev' ...
  final String iconKey;   // 双端各自映射到 IconData
  final String labelKey;  // l10n key
  final bool enabled;
}
```

UI 不再写 `if (book.format == 'pdf')`。

### 3.4 Locator 形状约定(批注/进度载体)

`Annotation` 模型(已有 bookmark/highlight/note)+ `Locator` 通用载体**不改**,仅约定各系形状:

| 系 | href | 定位 | extras |
|---|---|---|---|
| 文字系 | 章节路径 | cfi(或文本 quote) | — |
| 页面系 | 页路径 | — | `pageIndex` |
| 时间系 | 媒体文件 | — | `fileIndex, offset, totalDuration` |

配套 shared helper 把 locator 渲染成显示标签("第 12 页"/"12:34")。

## 4. 全格式谱系(路线图总表)

| 系 | 格式 | 实现形态 | 独有能力(超出"能翻页") |
|---|---|---|---|
| 文字系 | EPUB(.epub/.webpub) ✅ | WebView 渲染内核(现状) | 选词高亮/笔记、全文搜索、TOC、词典/翻译/朗读槽、外部链接、媒体灯箱 |
| | TXT | 编码探测(UTF-8/GBK…)+ 启发分章 → HTML → 同 EPUB 产物 | EPUB 全套文字能力 |
| | MOBI/AZW3 | 反解(PalmDOC/KF8)出 HTML 集 → 同 EPUB 产物(复用渲染内核,只换 parser) | 全套文字能力 + 排版保留 |
| 页面系 | CBZ/ZIP 漫画 ✅ | 原生图片 pager(现状) | 待补:页列表/缩略图、RTL(日漫)、整页书签+笔记、设置折叠 |
| | PDF | **Pdfium 原生**(每页渲染图像+原生手势);Pdfium 页树→大纲(书签树)→TOC;文本层探测→文本选择/搜索可用才声明 | 页列表、大纲、可选文本层能力 |
| 时间系 | 有声书(lpf/m4b/mp3 文件夹) | 原生音频引擎(全新) | 见 §7 |

## 5. 跨系统一

- **批注**:文字系=选词高亮/笔记;页面系=整页书签/笔记;时间系=时间书签。UI 由 `features.annotationKinds` 决定显示哪些入口(漫画无"添加高亮",有"在此页加书签/笔记")。
- **进度**:三系滑杆都 0..1,底层解释各异(文字=CFI/页序,页面=页,时间=累计播放时长)。`ReadingProgress.locator` 原样 round-trip(progress.json 已支持)。
- **统计**:阅读时长记录按 `bookUid`,格式无关。文字/页面系沿用停留计时;时间系由 play/pause 驱动(`ReadingSessionRecorder` 播放才记段),暂停切段。
- **主题/chrome**:主题与外壳对所有系一致(引擎是否消费主题色由各系决定)。

## 6. 文字系与页面系要点

### TXT
1. 编码探测:BOM → UTF-8 校验 → GBK/GB18030(Windows 大量存量)兜底。
2. 分章启发:纯文本按空行/常见章节标记(`第x章/Chapter`)切分;超长单文本按字数分卷。
3. 每章 → 一个 XHTML 文档,喂现有 epub 解析产物与渲染内核(reader_parser_epub / engine_epub 复用)。字节形状约束(manifest/positions/content.json)保持不变。

### MOBI/AZW3
- PalmDOC(旧 mobi,`<mbp:pagebreak>` 分章)与 KF8(azw3,实为 HTML 集)反解 → 同一产物。仅 parser 不同,渲染/批注/搜索全复用。版权/DRM 不在范围(无加密)。

### PDF
- 默认 **Pdfium 原生**:原生手势(缩放/平移)+ 每页渲染为图像;Pdfium 页面树可直接产出大纲(书签树)→ 映射 TOC;文本层存在时才声明 `textSelection=text` 与 `search`(无文本层=扫描版,退化为页面系能力:页书签/笔记)。
- 渲染方式备选(实现期评估):渲染线程池 + LRU 页缓存(参考漫画引擎经验,控内存)。

### 漫画 CBZ/ZIP(现状补齐方向)
- 页列表/缩略图(整卷缩略网格,点选跳页)、RTL(日漫从右往左翻,layout.direction=rtl)、整页书签+笔记(annotationKinds)、设置面板折叠(textTypography=false)。

## 7. 有声书(时间系)—— 最复杂,专项

### 7.1 格式三层(难度递增,无 DRM/LCP)
- `.mp3/.m4a/.ogg` 多文件/文件夹:文件名自然序 = 章序(最易,先行)。
- `.m4b`:mp4 容器 + 内嵌 chapter atoms → 媒体单文件 + 时间章节(中)。
- `.lpf`(W3C 有声书):zip 内 `manifest.json` 声明有序媒体清单 + 可选 SMIL 时序;含导航(readingOrder)(较繁)。

### 7.2 AudiobookParser(独立 parser 包/模块)
任意源 → 统一产物:
```
媒体列表[{file, duration?, title, 累计起始偏移}] + 元数据 + 章节(时间或文件级)
```
- 各源解析出媒体列表;m4b/lpf 解析章节;时长可缺(播放中获取)。

### 7.3 AudioPlaybackBackend(端口,引擎不绑库)
```
init / setMedia(list|single) / play / pause / seekTo(绝对ms) / setRate
position / duration / onComplete / onBuffered / dispose
```
- **移动**:just_audio + audio_service(后台媒体通知/锁屏控制)。
- **桌面**:just_audio_windows **先 spike 验证**(跑通即用;不行 fallback audioplayers)。端口抽象保证可换。
- 后台策略:移动常驻通知可锁屏控制;桌面窗口最小化继续播、退出停(迷你窗二期)。

### 7.4 AudioReaderSession
- 位置 = 当前媒体 + 偏移;`progression = 累计播放 / 总时长`。
- relocate **节流**:每 ~5s / seek / play-pause 才发(避免刷爆进度落库)。
- locator: `href=媒体文件, extras{fileIndex, offset, totalDuration}`。
- `goTo/seekToProgression` 按 进度/时间/章节 跳。
- `features`: textSelection=time → 时间书签;toc(章节)或按媒体分章;auxActions=上一章/下一章/±15s/速度;settingsOptions 近乎全关(+playback 速度)。
- `buildView` 音频面板:封面/标题/已播·总时长/速度/±15s/播放/上下章;复用外壳底栏总进度滑杆。
- 统计:play/pause 驱动计时。

### 7.5 边界
- 只播**实体音频文件**。文本转语音朗读整本(听书/TTS)= 另一位 agent 领地,不并入;EPUB 选词"朗读"弹层保持占位,不接 TTS。

## 8. 选择工具槽位(词典/翻译/朗读)

- 仅 `textSelection != none` 的系露出选择工具。占位现有:`dictionary_sheet/translation_sheet/tts_player_sheet`(mobile,目前内容为占位文案)。
- features.dictionary/translate/readAloud 声明**槽位是否显示**;服务实现(P5)再挂真后端。朗读若属 TTS 域,接入前确认边界(§7.5)。

## 9. 分阶段路线图

- **P0 契约 v2 + 双端 UI 描述驱动 + 本文档**(本次)
- **P1 漫画补齐**:页列表/缩略图、RTL、整页书签+笔记、设置折叠
- **P2 TXT → MOBI/AZW3**(parser 复用 epub 产物/渲染)
- **P3 PDF**(Pdfium 原生;先 spike 渲染线程/缓存)
- **P4 有声书**(mp3 文件夹 → m4b → lpf 渐进;桌面后端先 spike)
- **P5 hub/统计通用化 + 词典/翻译真功能 + 统计对全格式生效**

## 10. 决策记录 / 待验证

| 决策 | 状态 |
|---|---|
| 契约走"会话自描述 + UI 描述驱动",不做 page 内 if(format) | 已定(P0 实施) |
| PDF 用 Pdfium 原生 | 已定(默认) |
| 音频后端抽象端口;移动 just_audio+audio_service、桌面 spike 后定 | 待验证(spike) |
| Annotation 模型/Locator 不改,收敛为形状约定 | 已定 |
| 有声书范围=实体音频;TTS 朗读属另一 agent 不并入 | 已定 |
| 翻译/词典/朗读先留槽位,服务 P5 做真 | 已定 |

## 11. 范围外(本文档不覆盖)

- DRM/LCP、流式订阅内容、mobi 版权书。
- 整本 TTS 听书;EPUB 朗读真服务。
- 双端 ReaderPage 大重构(抽 shared_ui 统一 chrome)属工程质量项,另立;P0 只做描述驱动小改。
