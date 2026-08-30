---
spec_issue_number:
spec_issue_url:
spec_filed_at: 2026-08-30T00:00:00Z
spec_branch: main
spec_plan_mode: inactive
spec_executed: false
spec_worktree_path:
gate_score: 7/10 (codex, iteration 2)
decisions: D1 双端一次做完; D2 前台全额计时(gstack:stats-duration-semantics); D3 fl_chart+自绘热力图; D6 本地 docs 归档
---

# 阅读统计中心方案(Reading Statistics Center)

- 日期:2026-08-30 · 分支:main · 状态:已确认(D5),经 codex 门禁修订 1 轮
- 决策记录:双端一次做完(D1);时长口径=前台全额计时,无挂机检测(D2,gstack 决策 `stats-duration-semantics`);图表=fl_chart + 自绘热力图(D3);归档=本地 docs(D6)

## 1. 背景与价值

产品唯一用户对现有统计不满意:目前只有"我的"页一张 8 胶囊概览卡和移动端一个 10 行静态列表,没有任何阅读时长和连读数据——而这恰恰是阅读类产品最核心的指标。本方案交付:① "我的"页换上设计稿样式的周报卡(核心数据:连读天数+阅读时长);② 新增"统计中心"页,双端一致,含 5 大模块、4 类图表。排版基准=用户提供的移动端设计稿截图(本文件的像素值为规范,无其他设计资产);字体约束=仅用两端现有 Material 3 textTheme,不引入自定义字体。

## 2. 现状(已验证,2026-08-30)

| 事实 | 位置 | 影响 |
| --- | --- | --- |
| 无任何时长埋点(无字段/无表/无计时器) | 全仓库 | 须新增 `reading_sessions` 表 + Recorder |
| 无连读天数逻辑 | 全仓库 | 须新增计算(原料:session 的 day 桶) |
| 已完成书籍 = `cachedProgress >= 0.98` 启发式 | `apps/mobile/lib/features/me/controller/me_controller.dart:51` | 可复用 |
| 笔记/高亮计数 = O(N) 逐书读 JSONL | `me_controller.dart:101-136`(桌面在 `apps/desktop/lib/features/me/controller/me_controller.dart` 重复实现,阈值硬编码) | 可复用 |
| 桌面 Me 页统计不刷新(desktop reader dispose 无 invalidate;移动端参照 `apps/mobile/lib/features/reader/pages/reader_page.dart:1110-1115`) | `apps/desktop/lib/features/reader/pages/reader_page.dart` dispose | 本方案顺带修复 |
| drift schemaVersion=3,迁移约定"加 step、幂等防御" | `packages/infrastructure/data/lib/src/db/app_database.dart:8-27` | 新表走 v3→v4 step |
| 零图表库、零 CustomPainter;`intl ^0.20.2` 仅桌面 | 全部 pubspec(workspace 统一解析) | 新增 `fl_chart` |
| 移动端 Card 语言:radius 18 + outlineVariant 描边 + elevation 0 | `apps/mobile/lib/theme/app_theme.dart:41-49` | 统计中心复用 |
| 两端 reader 页均已 `with WidgetsBindingObserver` 且有完整 `didChangeAppLifecycleState` 分支(后台 flush / resumed) | 移动 `reader_page.dart:484-497`、桌面 `reader_page.dart:100-109` | Recorder 挂进现有分支,不新增 observer |
| 路由共享:`packages/foundation/application/lib/src/router/reader_app_router.dart`(`ReaderRoutePaths`/`ReaderAppRouterPages`/`buildReaderAppRouter`),镜像 `packages/shared_ui/lib/src/routes/route_paths.dart`,两端 `apps/mobile|desktop/lib/routes/app_router.dart` 各接线 lambda | — | `/stats` 注册共 5 处 |
| Me 页 tile 组件 `SettingsEntryTile`(移动/桌面各一) | `apps/*/lib/features/me/widgets/settings_entry_tile.dart` | 直接复用 |
| 移动端已有 `Navigator.push` 直推先例(统计详情页 `apps/mobile/lib/features/me/pages/stats_detail_page.dart`,由 `meControllerProvider` 供数) | `me_page.dart:73-83` | 删除之,统计中心改走 go_router `/stats` |
| DI:两端 `apps/mobile|desktop/lib/di/repositories_providers.dart` 已有 `annotationRepositoryProvider` 等模式 | — | 新增 `readingStatsRepositoryProvider` |

## 3. 功能与数据清单(统计中心 = 5 模块)

| # | 模块 | 数据 | 图表形式 | 时间窗 |
| --- | --- | --- | --- | --- |
| 1 | 核心指标 | 累计时长、当前连读/最长连读、已完成书籍、笔记高亮总数 | 4 个数字磁贴 | 全部累计 |
| 2 | 时长趋势 | 每日(周/月窗)或每月(年窗)阅读秒数 | fl_chart 柱状图 + 日均虚线 | 周/月/年切换 |
| 3 | 阅读热力图 | 按天秒数 | GitHub 风格日历格(GridView 自绘) | 近 15 周(桌面 20 周) |
| 4 | 时段分布 | 按 0-23 小时秒数 | 24 柱迷你柱状图 + 峰值文案 | 可选窗 |
| 5 | 书籍排行 | 按书秒数 Top5(+进度) | 封面+横向占比条列表 | 可选窗 |

口径(已定):**前台全额计时**——阅读页打开且 App 前台即累计,切后台/锁屏暂停,无挂机检测(代码留 `gstack-shortcut` 标记,升级触发=用户反馈时长虚增)。周=周一为始的自然周;连读=按本地自然日有阅读记录连续计。

## 4. 数据层设计

### 4.1 drift v3→v4(`packages/infrastructure/data/lib/src/db/app_database.dart`)

`schemaVersion` 3→4;`onUpgrade` 追加 `if (from < 4) await _upgradeToV4();`;`onCreate` 在 `_createCollectionsTables()` 后追加 `_createReadingSessionsTable()`:

```sql
CREATE TABLE IF NOT EXISTS reading_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bookUid TEXT NOT NULL,
  startedAt INTEGER NOT NULL,   -- epoch ms
  endedAt INTEGER NOT NULL,     -- epoch ms
  seconds INTEGER NOT NULL,     -- (endedAt-startedAt)/1000 向下取整,最小 0
  day TEXT NOT NULL,            -- 'yyyy-MM-dd' 本地日,来自 startedAt
  startHour INTEGER NOT NULL    -- 0-23,来自 startedAt
);
CREATE INDEX IF NOT EXISTS idx_reading_sessions_day ON reading_sessions(day);
CREATE INDEX IF NOT EXISTS idx_reading_sessions_book ON reading_sessions(bookUid);
```

跨午夜:60s 心跳切段使单段≤61s,按 `startedAt` 落日桶,误差≤1 分钟,不特殊处理。

### 4.2 领域端口(`packages/foundation/domain/lib/ports/repositories/reading_stats_repository.dart` + `packages/foundation/domain/lib/models/reading_stats.dart`)

```dart
abstract class ReadingStatsRepository {
  Future<void> recordSession({required String bookUid, required DateTime startedAt, required DateTime endedAt});
  Future<int> totalSeconds();
  Future<int> secondsBetween(DateTime from, DateTime to);                      // 区间 [from, to)
  Future<List<DailyReadingStat>> dailySeconds(DateTime from, DateTime to);     // 含 from 日,不含 to 日
  Future<List<MonthlyReadingStat>> monthlySeconds(DateTime from, DateTime to);
  Future<List<HourlyReadingStat>> hourlySeconds(DateTime from, DateTime to);   // 0-23 全量桶,无数据为 0
  Future<List<BookReadingStat>> topBooks(DateTime from, DateTime to, {int limit = 5});
  Future<StreakInfo> streak();                      // {currentDays, longestDays}
  Future<Set<String>> activeDays(DateTime from, DateTime to);                  // 有记录的 day 集合
}
```

模型(均为 const 构造 + final 字段,不序列化):`DailyReadingStat{String day; int seconds}`、`MonthlyReadingStat{String month; int seconds}`、`HourlyReadingStat{int hour; int seconds}`、`BookReadingStat{String bookUid; String title; String? coverRelPath; double? cachedProgress; int seconds}`、`StreakInfo{int currentDays; int longestDays}`。

实现 `ReadingStatsRepositoryImpl`(新文件 `packages/infrastructure/data/lib/src/repositories/reading_stats_repository_impl.dart`),构造注入 `AppDatabase`(经新 DAO `packages/infrastructure/data/lib/src/db/reading_stats_dao.dart`,raw SQL 风格同 `collection_dao.dart`);`DataModule`(`packages/infrastructure/data/lib/src/data_module.dart`)新增字段 `readingStatsRepository` 并在构造时装配;两端 `repositories_providers.dart` 新增:

```dart
final readingStatsRepositoryProvider = Provider<ReadingStatsRepository>(
  (ref) => ref.watch(dataModuleProvider).readingStatsRepository,
);
```

**孤儿策略**:`topBooks` 用 `LEFT JOIN library_index ON bookUid`,title 取 `COALESCE(li.title, ?)`(参数=双语"已删除的书籍"),cover/progress 为 null——已删书的时长仍计入总量与热力图,只在排行中显示兜底名。

### 4.3 计时器(`packages/shared_ui/lib/src/stats/reading_session_recorder.dart`)

```dart
class ReadingSessionRecorder {
  ReadingSessionRecorder({
    required this.bookUid,
    required void Function(DateTime startedAt, DateTime endedAt) onSegment,
    DateTime Function() now = DateTime.now,            // 测试注入
    Duration heartbeat = const Duration(seconds: 60),
  });
  void start();    // anchor=now,启动 Timer.periodic(heartbeat);重复调用 no-op
  void pause();    // 有 anchor 才动作:flush→清 anchor→停 Timer;幂等
  void resume();   // 无 anchor 才动作:anchor=now→启 Timer;幂等
  void dispose();  // pause() 兜底
}
```

**契约(消除实现歧义)**:
- **所有权**:Recorder 不依赖任何 repo、不注册自己的 WidgetsBindingObserver——生命周期完全由 ReaderPage 驱动(页面已有 observer)。onSegment 回调内部 `try/catch + debugPrint('[stats][record.error] $e')`,计时故障绝不影响阅读。
- **flush 语义**:一次 flush = `seconds = max(0, (ended - started).inSeconds)`;`seconds < 1` 不落库(零秒行不存在);`startedAt` 晚于 `now()+1min` 的段丢弃(防御时钟跳变)。心跳 tick=flush 旧段+重开新段,崩溃最多丢 60s。
- **并发**:产品为单窗口单 ReaderPage(go_router 单路由),同刻最多一个 Recorder 实例;comic/audio 页不创建 Recorder。若未来出现双阅读页,属新需求再议。
- **页面接线**(两端 `reader_page.dart` 各约 15 行):`initState` 末尾 `_recorder = ReadingSessionRecorder(bookUid: widget.bookUid, onSegment: (s, e) { try { unawaited(ref.read(readingStatsRepositoryProvider).recordSession(bookUid: widget.bookUid, startedAt: s, endedAt: e)); } catch (_) {} }); _recorder.start();`;现有 `didChangeAppLifecycleState` 后台分支加 `_recorder.pause()`,`resumed` 分支加 `_recorder.resume()`;`dispose` 第一行 `_recorder.dispose()`。
- **范围**:仅 `ReaderPage`(EPUB/PDF 引擎共用此页)。

### 4.4 日期与窗口语义(全方案统一定案)

- 一切时间用**本地时区** `DateTime.now()`,全程不做 UTC 转换;day 桶 = `DateFormat('yyyy-MM-dd').format(local)`(移动端需在 `apps/mobile/pubspec.yaml` 一并加 `intl`,与桌面同版本约束)。
- **周窗** = 本自然周周一 00:00 local 至现在;x 轴固定一~日 7 柱,未到的未来日为 0 高柱。
- **月窗** = 含今天的最近 30 天(today-29 .. today);x 轴 30 柱,每 5 天一个日期标签。
- **年窗** = 含当月的最近 12 个自然月,按 `month='yyyy-MM'` 聚合 12 柱。
- **区间约定**:仓储层所有 from/to 为 `[from, to)` 左闭右开;跨午夜段归 `startedAt` 所属日;`secondsBetween` 同规则。
- **连读**:`SELECT DISTINCT day` 全量取回,内存按"今天或昨天为锚点向前连续"算 `currentDays`;全集合最长连续段为 `longestDays`(两个日期串按字典序即时间序,无需解析)。
- **热力图**:列=自然周(旧→新,最后一列=本周,含未来日但渲染为底色且不可点);行=周一(顶)→周日(底);首列允许不满 7 格(窗口起点对齐 15/20 周前的周一)。

## 5. 排版方案(像素级;规范来源=用户设计稿截图+本文件)

### 5.1 "我的"页周报卡 v2(双端同构)

组件归属:新文件 `packages/shared_ui/lib/src/widgets/weekly_report_card_v2.dart`(两端 me_page 引用;桌面传入 `formatDateTime` 无需——v2 不含时间戳行)。

位置:两端 `me_page.dart` 原 `WeeklyReportCard` 处;上方 section header `本周周报`(key `weeklySectionTitle`),样式沿用现有 header(`titleSmall`,底部 8px)。

卡片:`Container` 替代 `Card`;`BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFCE7EE), Color(0xFFF6E3F8)], begin: topLeft, end: bottomRight), borderRadius: BorderRadius.circular(18))`;暗色 `[Color(0xFF3B2B33), Color(0xFF332B3E)]`;`padding: EdgeInsets.all(16)`;整卡 `InkWell(borderRadius: 18, onTap: () => context.push(RoutePaths.stats))`。

内部(Column,行距 10;文字色:亮色模式 `Color(0xFF1C1B1F)`,暗色 `Color(0xFFE6E1E5)`,即 onSurface):

1. `核心数据` — 11sp w500,onSurface 54%,letterSpacing 0.5
2. Row:`Icon(Icons.local_fire_department, size:20, color:Color(0xFFFF7043))` → 8px → `坚持`(14sp w400)→ 4px → `7`(20sp w700,`Color(0xFFE5484D)`)→ 4px → `天连续阅读`(14sp w400)
3. Row:`Icon(Icons.timer_outlined, size:20, color:Color(0xFF26A69A))` → 8px → `共阅读`(14sp)→ 4px → `27小时17分钟`(16sp w600,亮 `Color(0xFF0C7D69)`/暗用 `colorScheme.primary`)
4. `次要数据` — 同 1
5. Row:`Icon(Icons.menu_book_outlined, size:18)` + 8px + `已完成书籍数`(14sp)→ `Spacer` → `3`(16sp w700,`Color(0xFFE5484D)`)
6. Row:`Icon(Icons.location_history, size:18)` + 8px + `笔记 / 高亮数`(14sp)→ `Spacer` → `47`(16sp w700,`Color(0xFF26A69A)`)
7. Align(right):`Icon(Icons.chevron_right, size:16, onSurface 42%)`

数据源:连读=`streak().currentDays`;本周时长=`secondsBetween(本周一00:00, now)`;已完成/笔记高亮=现有 `MeState.completedBooks`、`highlightsCount + notesCount`(MeController 不动,卡片在两端 me_page 内用 `ref.watch(meControllerProvider)` + 新 `ref.watch(weeklyReadingSummaryProvider)`(见 5.3)双源拼接)。

### 5.2 统计中心页 `/stats`

**组件归属**:页面=两端各自 `apps/mobile|desktop/lib/features/stats/pages/stats_center_page.dart`(双端同构,`LayoutBuilder` 断点 900 分支);共享子组件在 `packages/shared_ui/lib/src/stats/`:`stats_range_segmented.dart`、`stats_overview_grid.dart`、`stats_trend_card.dart`、`reading_heatmap.dart`、`stats_hourly_card.dart`、`stats_top_books_card.dart`、`stats_state.dart`(枚举+聚合 state+格式化)。

**数据供给**:新 `statsCenterProvider`(两端 `di/providers.dart` 或页面内 `FutureProvider.autoDispose<StatsCenterData>`),并发取 `totalSeconds/streak/dailySeconds|monthlySeconds/hourlySeconds/topBooks/activeDays` + `meControllerProvider` 的标注计数;窗口切换=参数化 family 或本地 StateNotifier 持 range 后 refetch;两端 `reader_page.dart` `dispose` 的 invalidate 列表加 `statsCenterProvider`(移动端已有 invalidate 块 1110-1115 处追加;桌面端新增该块)。

**页面骨架**:`Scaffold`+`AppBar(title: 统计中心)`;body `ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24))`;节间距 16;卡片=两端默认 Card。

**头部行**:AppBar 下第一行,`SegmentedButton<StatsRange>`(周/月/年,`showSelectedIcon:false`,dense)。

**模块 1 核心指标**:单卡内 `2×2`(桌面 `1×4`);每磁贴 Column:图标 20sp → 6px → 数值 `24sp w700`(时长 `X小时Y分钟`,<1h 显示 `N 分钟`)→ 2px → 标签 `12sp secondary` → 2px → 副文本 `11sp tertiary`;磁贴间 `VerticalDivider(width:12, color: outlineVariant)` 与 `SizedBox(height:12)`。四磁贴:⏱ 累计阅读(副:`共 N 天有阅读`)/🔥 连续阅读(值 `N 天`,副 `最长 M 天`)/📚 已完成(副 `总藏书 T 本`)/📍 笔记与高亮(副 `高亮 h · 笔记 n · 书签 b`)。

**模块 2 时长趋势**:卡 padding 14;卡头 Row:标题 `16sp w600` + Spacer + `日均 X 分钟`(`11sp` primary;日均=窗内总秒/窗内有记录天数,无记录显示 `日均 0 分钟`);`SizedBox(height:200, BarChart)`;柱色:最新有数据日=`primary`,余=`primaryContainer`;横网格线 `outlineVariant` 宽 0.5,纵线无;y 轴隐;tooltip=反色胶囊(`colorScheme.inverseSurface`/`onInverseSurface`),文案 `M月d日 · X小时Y分钟`(年窗=`yyyy年M月 · X小时Y分钟`)。

**模块 3 阅读热力图**(共享组件 `reading_heatmap.dart`):卡 padding 14;网格 `GridView.count` 自绘:格 14×14 radius 3 间距 3(桌面 16/4/间距 4);月份标签 `10sp tertiary` 吸顶行;星期标签列仅 `一/三/五`;色阶:<15min=25% primary、<30min=50%、<60min=75%、≥60min=primary、无= surfaceContainerHighest;未来日=底色 40% 且 IgnorePointer;底部 Row:左图例 `少 ▫▫▫▫ 多`(10sp tertiary)右留白;点击格→图例行左侧文字替换为 `M月d日:X小时Y分钟`(`SizedBox(height:18)` 预留防跳动)。

**模块 4 时段分布**:卡;卡头:标题 + Spacer + `最常在 21 点`(`11sp` primary;峰值=秒数最大且>0 的小时,全 0 显示 `暂无`);`SizedBox(height:140)` 24 柱 BarChart,仅 `0/6/12/18` 轴标签,峰值柱 `primary`,余 `primaryContainer`,无网格线,tooltip 同模块 2(`21点 · 2小时3分钟`)。

**模块 5 书籍排行**:卡;`Column` 每行 `SizedBox(height:64)`:封面 `40×56, radius 6`(coverRelPath 空→`surfaceContainerHighest` 底+`Icons.book_outlined` 居中)+12px→Expanded Column(书名 `14sp w500` ellipsis+8px+占比条:`ClipRRect(radius:3)` 高 6,背景 `surfaceContainerHighest`,前景 `FractionallySizedBox(widthFactor: 份额, child: Container(color: primary.withValues(alpha: .7)))`)+12px→右列(时长 `12sp w600`/4px/`ProgressBadge(cachedProgress)`,null 不显示)。Top5 不足显示实际数;窗口内无数据整节隐藏。

**空状态**:全库无 session → 页 body=`EmptyView(title: '阅读之旅尚未开始', message: '打开一本书开始阅读,这里会出现你的足迹')`;单节无数据→整节隐藏(热力图除外,渲染全灰格)。

**桌面排版**(≥900):`Center > ConstrainedBox(maxWidth:1080)`;`ListView > Column`:头部行(Row:标题左+SegmentedButton 右);模块1 1×4;`Row(crossAxisAlignment: start)`:模块2 `Expanded(flex:2)` + 16px + 模块4 `Expanded(flex:1)`;模块3 全宽;模块5 全宽(封面 48×68,行高 72)。<900 与移动端同构。

**导航/入口**:`ReaderRoutePaths.stats='/stats'` + `ReaderAppRouterPages.statsBuilder` + `buildReaderAppRouter` 加 GoRoute(共享 router)+ 两端 `app_router.dart` lambda(`(context, state) => StatsCenterPage()`)。移动端 me_page 快捷入口:删除`统计详情` tile 与 `stats_detail_page.dart`,首位插入`统计中心` tile(`Icons.insights`);桌面 me_page 同位置新增(桌面此前无入口)。两端周报卡 v2 点击同样进入。

**l10n 全量字符串(zh / en)**:

| key | zh | en |
| --- | --- | --- |
| weeklySectionTitle | 本周周报 | Weekly report |
| statsCenterTitle | 统计中心 | Statistics |
| statsRangeWeek/Month/Year | 周/月/年 | W/M/Y |
| statsTotalTime | 累计阅读 | Total reading |
| statsCurrentStreak | 连续阅读 | Reading streak |
| statsLongestStreakSuffix | 最长 {days} 天 | Longest {days} d |
| statsFinishedBooks | 已完成 | Finished |
| statsTotalBooksSuffix | 总藏书 {count} 本 | {count} books total |
| statsNotesHighlights | 笔记与高亮 | Notes & highlights |
| statsDaysWithReadingSuffix | 共 {days} 天有阅读 | {days} active days |
| statsTrendSection | 阅读时长 | Reading time |
| statsHeatmapSection | 阅读热力图 | Activity |
| statsHourlySection | 时段分布 | By hour |
| statsBooksSection | 书籍排行 | Top books |
| statsDailyAvg | 日均 {minutes} 分钟 | {minutes} min/day |
| statsPeakHour | 最常在 {hour} 点 | Peak at {hour}h |
| statsLess/statsMore | 少/多 | Less/More |
| statsEmptyTitle | 阅读之旅尚未开始 | Your journey starts here |
| statsEmptyMessage | 打开一本书开始阅读,这里会出现你的足迹 | Open a book and your footprint appears here |
| statsHoursMinutes(h,m) | {h}小时{m}分钟 | {h}h {m}m |
| statsMinutes(m) | {m} 分钟 | {m} min |
| statsDateDuration(d, s) | {d}:{s} | {d}: {s} |
| statsDeletedBook | 已删除的书籍 | Deleted book |

桌面 arb 加 key 后 `cd apps/desktop && flutter gen-l10n`(带占位符的 key 用 ICU `{placeholder}`);移动端在 `apps/mobile/lib/l10n/l10n.dart` 的 `MobileStrings` 加 getter(`_isZh ? ... : ...`,带参 getter 用普通函数签名)。

## 6. 文件清单(完整路径)

| 文件 | 变更 |
| --- | --- |
| `packages/infrastructure/data/lib/src/db/app_database.dart` | schemaVersion 4;`_createReadingSessionsTable()`;`_upgradeToV4()` |
| `packages/infrastructure/data/lib/src/db/reading_stats_dao.dart` | 新增 |
| `packages/infrastructure/data/lib/src/repositories/reading_stats_repository_impl.dart` | 新增 |
| `packages/infrastructure/data/lib/src/data_module.dart` | +`readingStatsRepository` 字段与装配 |
| `packages/infrastructure/data/test/reading_stats_repository_impl_test.dart` | 新增(DAO+仓库用例) |
| `packages/infrastructure/data/test/app_database_migration_test.dart` | +v3→v4 用例 |
| `packages/foundation/domain/lib/ports/repositories/reading_stats_repository.dart` | 新增端口 |
| `packages/foundation/domain/lib/models/reading_stats.dart` | 新增 5 模型;domain barrel 导出 |
| `packages/shared_ui/lib/src/stats/reading_session_recorder.dart` | 新增 |
| `packages/shared_ui/lib/src/stats/stats_state.dart` | 新增(StatsRange 枚举、StatsCenterData、时长格式化) |
| `packages/shared_ui/lib/src/stats/stats_range_segmented.dart` / `stats_overview_grid.dart` / `stats_trend_card.dart` / `stats_hourly_card.dart` / `stats_top_books_card.dart` | 新增共享组件 |
| `packages/shared_ui/lib/src/widgets/reading_heatmap.dart`、`weekly_report_card_v2.dart` | 新增 |
| `packages/shared_ui/lib/shared_ui.dart` | barrel 导出上述 |
| `packages/shared_ui/test/reading_session_recorder_test.dart`、`reading_heatmap_test.dart`、`weekly_report_card_v2_test.dart` | 新增 |
| `apps/mobile/pubspec.yaml`、`apps/desktop/pubspec.yaml` | +`fl_chart ^0.69.0`;mobile +`intl ^0.20.2`(与桌面同约束) |
| `apps/mobile/lib/di/repositories_providers.dart`、`apps/desktop/lib/di/repositories_providers.dart` | +`readingStatsRepositoryProvider` |
| `apps/mobile/lib/features/reader/pages/reader_page.dart` | Recorder 接线;invalidate 加 statsCenter |
| `apps/desktop/lib/features/reader/pages/reader_page.dart` | 同上(此前无 invalidate 块,新增) |
| `apps/mobile/lib/features/me/pages/me_page.dart`、`apps/desktop/lib/features/me/pages/me_page.dart` | 换周报卡 v2;tile 增删 |
| `apps/mobile/lib/features/me/pages/stats_detail_page.dart` | 删除 |
| `apps/mobile/lib/features/stats/pages/stats_center_page.dart`、`apps/desktop/lib/features/stats/pages/stats_center_page.dart` | 新页面 |
| `packages/foundation/application/lib/src/router/reader_app_router.dart`、`packages/shared_ui/lib/src/routes/route_paths.dart`、两端 `lib/routes/app_router.dart` | `/stats` 注册 |
| `apps/mobile/lib/l10n/l10n.dart` | +getter(上表) |
| `apps/desktop/lib/l10n/arb/app_en.arb`、`app_zh.arb` + 生成文件 | +key;`flutter gen-l10n` |

## 7. 验收标准(可测,含容差)

1. 阅读页前台满 65 秒(≥1 个心跳),退出后"累计阅读时长"≥60 秒;期间切后台的时长不计(后台分支 pause)。
2. 连续 2 个自然日各 ≥1 分钟,周报卡"坚持"=2;跳过一天后阅读,重置为 1(用 DAO fixture 驱动,不靠真实等待)。
3. 周/月/年切换,x 轴桶数=7/30/12(含未来零柱);任一柱 tooltip 数值 == DAO `dailySeconds/monthlySeconds` 对应桶值。
4. 热力图列数=15(桌面 20),最后一列为本周且未来格不可点;点击有数据格,底部文案显示该日时长。
5. 时段分布峰值文案==`hourlySeconds` 最大非零桶;Top5 时长之和 ≤ 窗口总时长;删除书籍后排行显示"已删除的书籍"。
6. 无数据新装:页面 EmptyView、周报卡 0 天/0 小时、无异常日志。
7. 迁移:v3 库升级后 `PRAGMA table_info(reading_sessions)` 含 7 列且旧表数据不变(migration test 断言)。
8. `dart analyze` 全仓零问题;双端中英文案齐全;桌面读书返回 Me/统计页数据即时刷新(dispose invalidate)。

## 8. 测试计划

| 层 | 内容 | 数量 |
| --- | --- | --- |
| Unit(DAO/仓库) | 日桶/时桶/月桶分组;`[from,to)` 边界;跨午夜段归起点日;连读 current/longest(跨日 fixture);孤儿 JOIN 兜底名;空库全查询 | +7 |
| Unit(Recorder) | fake_async:start/pause/resume/heartbeat/dispose;幂等;零秒不落库;时钟跳变丢弃 | +5 |
| Unit(迁移) | v3→v4 列存在+旧数据保持 | +1 |
| Widget | 周报卡 v2 四指标(固定 fixture);StatsCenterPage 三窗口渲染关键文本(峰值/日均/Top 书名);EmptyView | +3 |
| 手动 | 平板+Windows:验收 1/4/8 | — |

## 9. 工作量与顺序

A 数据层+迁移(3h)→ B Recorder+双端接线(2h)→ C 周报卡 v2(2h)→ D 统计中心共享组件+移动端页(5h)→ E 桌面布局+invalidate 修复(3h)→ F 测试+l10n 收尾(3h)。**B 完成即可发内部包开始攒数据,页面后补不丢历史**——顺序不可调换 A/B 与 C/D/E 的先后。

## 10. 回滚

新表纯增量,回滚=revert 提交;老代码不读 `reading_sessions`,schemaVersion 回退无副作用;Recorder 接线点少,revert 干净。

## 11. 范围外(明确不做)

云同步统计、成就徽章、导出分享、阅读目标/提醒、comic/audio 时长、每章时长、标注动态趋势图(M2 候选)、历史时长回填(技术上不可能)、双窗口同时计时。

## 附:门禁后补注(codex 7/10 残余项钉死)

- `weeklyReadingSummaryProvider`:定义在两端 `apps/mobile|desktop/lib/di/services_providers.dart`,`FutureProvider.autoDispose<WeeklyReadingSummary>`,内部并发取 `readingStatsRepositoryProvider.streak()` 与 `secondsBetween(本周一, now)`;`WeeklyReadingSummary{int streakDays; int weekSeconds}` 定义放 `packages/shared_ui/lib/src/stats/stats_state.dart`。
- 热力图组件统一路径:`packages/shared_ui/lib/src/stats/reading_heatmap.dart`(§6 中 widgets/ 下那条作废,以本条为准)。
