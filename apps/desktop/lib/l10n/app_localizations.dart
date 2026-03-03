import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }

  bool get _isZh => locale.languageCode.toLowerCase().startsWith('zh');

  String get appTitle => _isZh ? 'Reader 桌面端' : 'Reader Desktop';
  String get settings => _isZh ? '设置' : 'Settings';
  String get tabReadingNow => _isZh ? '阅读中' : 'Reading';
  String get tabLibrary => _isZh ? '书架' : 'Library';
  String get tabMe => _isZh ? '我的' : 'Me';

  String get libraryTitle => _isZh ? '书架' : 'Library';
  String get loadingFailed => _isZh ? '加载失败' : 'Load failed';
  String get emptyLibrary =>
      _isZh ? '暂无书籍，先导入一本书。' : 'No books yet. Import one first.';
  String get filter => _isZh ? '筛选' : 'Filter';
  String get sort => _isZh ? '排序' : 'Sort';
  String get sortByRecentRead => _isZh ? '最近阅读' : 'Recent reading';
  String get sortByImportedAt => _isZh ? '最近导入' : 'Recently imported';
  String get sortByName => _isZh ? '名称 A-Z' : 'Name A-Z';
  String get format => _isZh ? '格式' : 'Format';
  String get progress => _isZh ? '进度' : 'Progress';
  String get category => _isZh ? '分类' : 'Category';
  String get collection => _isZh ? '合集' : 'Collection';
  String get all => _isZh ? '全部' : 'All';
  String get allCollections => _isZh ? '全部合集' : 'All collections';
  String get unknownCollection => _isZh ? '未知合集' : 'Unknown collection';
  String get currentCollection => _isZh ? '当前合集' : 'Current collection';
  String get notStarted => _isZh ? '未开始' : 'Not started';
  String get inProgress => _isZh ? '阅读中' : 'In progress';
  String get completed => _isZh ? '已完成' : 'Completed';
  String get newCollection => _isZh ? '新建合集' : 'New collection';
  String get manageCollection => _isZh ? '管理合集' : 'Manage collections';
  String get collapseFilterPanel => _isZh ? '收起筛选栏' : 'Collapse filters';
  String get expandFilterPanel => _isZh ? '展开筛选栏' : 'Expand filters';
  String get grid => _isZh ? '网格' : 'Grid';
  String get list => _isZh ? '列表' : 'List';
  String get refresh => _isZh ? '刷新' : 'Refresh';
  String get importBook => _isZh ? '导入' : 'Import';
  String get selectBookToViewDetail =>
      _isZh ? '选择一本书查看详情' : 'Select a book to view details';
  String get author => _isZh ? '作者' : 'Author';
  String get uncategorized => _isZh ? '未分类' : 'Uncategorized';
  String get importedAt => _isZh ? '导入时间' : 'Imported at';
  String get lastOpened => _isZh ? '最近阅读' : 'Last opened';
  String get continueReading => _isZh ? '继续阅读' : 'Continue';
  String get openToc => _isZh ? '打开目录' : 'Open TOC';
  String get deleteBook => _isZh ? '删除书籍' : 'Delete book';
  String get addOrRemoveCollection =>
      _isZh ? '加入/移出合集' : 'Add/Remove collection';
  String get noCollectionAdded => _isZh ? '未加入合集' : 'No collection';
  String get renameCollection => _isZh ? '重命名合集' : 'Rename collection';
  String get inputCollectionName => _isZh ? '输入合集名称' : 'Input collection name';
  String get inputCollectionNewName => _isZh ? '输入新名称' : 'Input new name';
  String get noCollectionYet => _isZh ? '还没有合集' : 'No collections yet';
  String get noCollectionCreateFirst =>
      _isZh ? '还没有合集，请先创建。' : 'No collections, create one first.';
  String get close => _isZh ? '关闭' : 'Close';
  String get done => _isZh ? '完成' : 'Done';
  String get create => _isZh ? '创建' : 'Create';
  String get save => _isZh ? '保存' : 'Save';
  String get cancel => _isZh ? '取消' : 'Cancel';
  String get exit => _isZh ? '退出' : 'Exit';
  String get confirmExitMessage =>
      _isZh ? '确认退出应用吗？' : 'Do you want to exit now?';
  String get delete => _isZh ? '删除' : 'Delete';
  String get confirmDeleteTitle => _isZh ? '删除确认' : 'Confirm delete';
  String get confirmDeleteMessage =>
      _isZh ? '删除后不可恢复，是否继续？' : 'This action cannot be undone. Continue?';
  String get imported => _isZh ? '导入成功' : 'Imported';
  String get importFailed => _isZh ? '导入失败' : 'Import failed';
  String get alreadyImported => _isZh ? '已导入' : 'Already imported';

  String collectionsForBookTitle(String title) =>
      _isZh ? '合集 · $title' : 'Collections · $title';

  String booksCount(int count) => _isZh ? '$count 本书' : '$count books';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    return code == 'en' || code == 'zh';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
