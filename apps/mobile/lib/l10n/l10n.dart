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
  String get imageLoadFailed => _isZh ? '图片加载失败' : 'Image failed to load';
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
