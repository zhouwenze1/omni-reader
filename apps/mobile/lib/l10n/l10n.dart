import 'package:flutter/widgets.dart';

class MobileStrings {
  const MobileStrings(this.locale);

  final Locale locale;

  bool get _isZh => locale.languageCode.toLowerCase().startsWith('zh');

  String get appTitle => _isZh ? '阅读器' : 'Reader Mobile';
  String get reader => _isZh ? '阅读器' : 'Reader';
  String get readerSettings => _isZh ? '阅读设置' : 'Reader settings';
  String get display => _isZh ? '显示' : 'Display';
  String get typography => _isZh ? '排版' : 'Typography';
  String get fontSize => _isZh ? '字体大小' : 'Font size';
  String get lineHeight => _isZh ? '行高' : 'Line height';
  String get pageGap => _isZh ? '页间距' : 'Page gap';
  String get theme => _isZh ? '主题' : 'Theme';
  String get dayTheme => _isZh ? '白天' : 'Day';
  String get nightTheme => _isZh ? '夜间' : 'Night';
  String get sepiaTheme => _isZh ? '护眼' : 'Sepia';
  String get layoutMode => _isZh ? '阅读模式' : 'Layout mode';
  String get layoutAuto => _isZh ? '自适应' : 'Auto';
  String get layoutSingle => _isZh ? '单页' : 'Single';
  String get layoutSpread => _isZh ? '双页' : 'Spread';
  String get layoutBoundary => _isZh ? '分页滚动' : 'Boundary';
  String get layoutContinuous => _isZh ? '连续滚动' : 'Continuous';
  String get layoutAutoHint => _isZh
      ? '自适应模式会在手机上使用单页，在更大屏幕上使用双页。'
      : 'Auto uses a single page on phones and a spread on larger screens.';
  String get enableTextIndent => _isZh ? '启用首行缩进' : 'Enable text indent';
  String get textIndent => _isZh ? '首行缩进' : 'Text indent';
  String get indentSize => _isZh ? '缩进大小' : 'Indent size';
  String get skipFirstParagraphIndent =>
      _isZh ? '首段不缩进' : 'Skip first paragraph indent';
  String get search => _isZh ? '搜索' : 'Search';
  String get switchThemeQuick => _isZh ? '快速切换日夜' : 'Toggle theme';
  String get toc => _isZh ? '目录' : 'Contents';
  String get annotations => _isZh ? '标注' : 'Annotations';
  String get highlights => _isZh ? '高亮' : 'Highlights';
  String get notes => _isZh ? '笔记' : 'Notes';
  String get bookmarks => _isZh ? '书签' : 'Bookmarks';
  String get more => _isZh ? '更多' : 'More';
  String get previousPage => _isZh ? '上一页' : 'Prev';
  String get nextPage => _isZh ? '下一页' : 'Next';
  String get debugInfo => _isZh ? '调试信息' : 'Debug info';
  String get pdfOutline => _isZh ? 'PDF 大纲' : 'PDF outline';
  String get pdfThumbnails => _isZh ? 'PDF 缩略图' : 'PDF thumbnails';
  String get audioPlayer => _isZh ? '音频播放器' : 'Audio player';
  String get comicMode => _isZh ? '漫画模式' : 'Comic mode';
  String get annotationHubTitle => _isZh ? '标注内容' : 'Annotations';
  String get moreActionsTitle => _isZh ? '更多操作' : 'More actions';
  String get annotationNote => _isZh ? '标注笔记' : 'Annotation note';
  String get save => _isZh ? '保存' : 'Save';
  String get cancel => _isZh ? '取消' : 'Cancel';
  String get copied => _isZh ? '已复制' : 'Copied';
  String get highlightAdded => _isZh ? '已添加高亮' : 'Highlight added';
  String get highlightFailed => _isZh ? '高亮操作失败' : 'Highlight failed';
  String get imageLoadFailed => _isZh ? '图片加载失败' : 'Image failed to load';

  // —— 阅读统计(周报卡 v2 + 统计中心)——
  String get weeklySectionTitle => _isZh ? '本周周报' : 'Weekly report';
  String get statsCenterTitle => _isZh ? '统计中心' : 'Statistics';
  String get statsEmptyTitle => _isZh ? '阅读之旅尚未开始' : 'Your journey starts here';
  String get statsEmptyMessage => _isZh
      ? '打开一本书开始阅读，这里会出现你的足迹'
      : 'Open a book and your footprint appears here';
  String get statsCoreDataTitle => _isZh ? '核心数据' : 'Core';
  String get statsSecondaryDataTitle => _isZh ? '次要数据' : 'More';
  String get statsStreakPrefix => _isZh ? '坚持' : 'Streak';
  String get statsStreakSuffix => _isZh ? '天连续阅读' : 'days in a row';
  String get statsTotalTimePrefix => _isZh ? '共阅读' : 'Read';
  String get statsFinishedBooksLabel => _isZh ? '已完成书籍数' : 'Books finished';
  String get statsNotesHighlightsLabel =>
      _isZh ? '笔记 / 高亮数' : 'Notes / highlights';
  String get statsCenterEntry => _isZh ? '统计中心' : 'Statistics center';
  String statsHoursMinutes(int hours, int minutes) =>
      _isZh ? '$hours小时$minutes分钟' : '${hours}h ${minutes}m';
  String statsMinutes(int minutes) => _isZh ? '$minutes 分钟' : '$minutes min';
}

Locale? mobileLocaleFromPreference(String localeCode) {
  switch (localeCode) {
    case 'zh-CN':
      return const Locale('zh', 'CN');
    case 'en':
      return const Locale('en');
    default:
      return null;
  }
}

extension MobileL10nX on BuildContext {
  MobileStrings get l10n {
    final locale =
        Localizations.maybeLocaleOf(this) ?? const Locale('zh', 'CN');
    return MobileStrings(locale);
  }
}
