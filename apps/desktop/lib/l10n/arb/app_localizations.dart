import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader Desktop'**
  String get appTitle;

  /// No description provided for @appBrandName.
  ///
  /// In en, this message translates to:
  /// **'OmniBook'**
  String get appBrandName;

  /// No description provided for @appVersionText.
  ///
  /// In en, this message translates to:
  /// **'Version: 1.0.0 (Build dev)'**
  String get appVersionText;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @tabReadingNow.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get tabReadingNow;

  /// No description provided for @tabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// No description provided for @tabMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabMe;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @loadingFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get loadingFailed;

  /// No description provided for @emptyLibrary.
  ///
  /// In en, this message translates to:
  /// **'No books yet. Import one first.'**
  String get emptyLibrary;

  /// No description provided for @loadingReadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Loading reading history...'**
  String get loadingReadingHistory;

  /// No description provided for @emptyReadingNowTitle.
  ///
  /// In en, this message translates to:
  /// **'No active books'**
  String get emptyReadingNowTitle;

  /// No description provided for @emptyReadingNowMessage.
  ///
  /// In en, this message translates to:
  /// **'Import a book in Library to start reading.'**
  String get emptyReadingNowMessage;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortByRecentRead.
  ///
  /// In en, this message translates to:
  /// **'Recent reading'**
  String get sortByRecentRead;

  /// No description provided for @sortByImportedAt.
  ///
  /// In en, this message translates to:
  /// **'Recently imported'**
  String get sortByImportedAt;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name A-Z'**
  String get sortByName;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allCollections.
  ///
  /// In en, this message translates to:
  /// **'All collections'**
  String get allCollections;

  /// No description provided for @unknownCollection.
  ///
  /// In en, this message translates to:
  /// **'Unknown collection'**
  String get unknownCollection;

  /// No description provided for @currentCollection.
  ///
  /// In en, this message translates to:
  /// **'Current collection'**
  String get currentCollection;

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get notStarted;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @manageCollection.
  ///
  /// In en, this message translates to:
  /// **'Manage collections'**
  String get manageCollection;

  /// No description provided for @collapseFilterPanel.
  ///
  /// In en, this message translates to:
  /// **'Collapse filters'**
  String get collapseFilterPanel;

  /// No description provided for @expandFilterPanel.
  ///
  /// In en, this message translates to:
  /// **'Expand filters'**
  String get expandFilterPanel;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @importBook.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importBook;

  /// No description provided for @selectBookToViewDetail.
  ///
  /// In en, this message translates to:
  /// **'Select a book to view details'**
  String get selectBookToViewDetail;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @importedAt.
  ///
  /// In en, this message translates to:
  /// **'Imported at'**
  String get importedAt;

  /// No description provided for @lastOpened.
  ///
  /// In en, this message translates to:
  /// **'Last opened'**
  String get lastOpened;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueReading;

  /// No description provided for @openToc.
  ///
  /// In en, this message translates to:
  /// **'Open TOC'**
  String get openToc;

  /// No description provided for @deleteBook.
  ///
  /// In en, this message translates to:
  /// **'Delete book'**
  String get deleteBook;

  /// No description provided for @addOrRemoveCollection.
  ///
  /// In en, this message translates to:
  /// **'Add/Remove collection'**
  String get addOrRemoveCollection;

  /// No description provided for @noCollectionAdded.
  ///
  /// In en, this message translates to:
  /// **'No collection'**
  String get noCollectionAdded;

  /// No description provided for @renameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get renameCollection;

  /// No description provided for @inputCollectionName.
  ///
  /// In en, this message translates to:
  /// **'Input collection name'**
  String get inputCollectionName;

  /// No description provided for @inputCollectionNewName.
  ///
  /// In en, this message translates to:
  /// **'Input new name'**
  String get inputCollectionNewName;

  /// No description provided for @noCollectionYet.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get noCollectionYet;

  /// No description provided for @noCollectionCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'No collections, create one first.'**
  String get noCollectionCreateFirst;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @confirmExitMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to exit now?'**
  String get confirmExitMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. Continue?'**
  String get confirmDeleteMessage;

  /// No description provided for @imported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get imported;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already imported'**
  String get alreadyImported;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @moveSelectedBooks.
  ///
  /// In en, this message translates to:
  /// **'Move selected books'**
  String get moveSelectedBooks;

  /// No description provided for @targetCollection.
  ///
  /// In en, this message translates to:
  /// **'Target collection'**
  String get targetCollection;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @batchActions.
  ///
  /// In en, this message translates to:
  /// **'Batch actions'**
  String get batchActions;

  /// No description provided for @moveToCollection.
  ///
  /// In en, this message translates to:
  /// **'Move to collection'**
  String get moveToCollection;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// No description provided for @exitMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Exit multi-select'**
  String get exitMultiSelect;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettings;

  /// No description provided for @readerSettings.
  ///
  /// In en, this message translates to:
  /// **'Reader settings'**
  String get readerSettings;

  /// No description provided for @cloudSettings.
  ///
  /// In en, this message translates to:
  /// **'Cloud settings'**
  String get cloudSettings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @chineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get chineseSimplified;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @debugImportLogs.
  ///
  /// In en, this message translates to:
  /// **'Import debug logs'**
  String get debugImportLogs;

  /// No description provided for @debugImportLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write debug-import.json for troubleshooting.'**
  String get debugImportLogsSubtitle;

  /// No description provided for @autoCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto-check updates'**
  String get autoCheckUpdate;

  /// No description provided for @sendAnonymousUsage.
  ///
  /// In en, this message translates to:
  /// **'Send anonymous usage data'**
  String get sendAnonymousUsage;

  /// No description provided for @cloudService.
  ///
  /// In en, this message translates to:
  /// **'Cloud service'**
  String get cloudService;

  /// No description provided for @storageProvider.
  ///
  /// In en, this message translates to:
  /// **'Storage provider'**
  String get storageProvider;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto sync'**
  String get autoSync;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get advancedOptions;

  /// No description provided for @storeOriginalFiles.
  ///
  /// In en, this message translates to:
  /// **'Store original files'**
  String get storeOriginalFiles;

  /// No description provided for @storeProgress.
  ///
  /// In en, this message translates to:
  /// **'Store reading progress'**
  String get storeProgress;

  /// No description provided for @storeNotes.
  ///
  /// In en, this message translates to:
  /// **'Store notes'**
  String get storeNotes;

  /// No description provided for @storeHighlights.
  ///
  /// In en, this message translates to:
  /// **'Store highlights'**
  String get storeHighlights;

  /// No description provided for @storeAppData.
  ///
  /// In en, this message translates to:
  /// **'Store app data'**
  String get storeAppData;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display settings'**
  String get displaySettings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get themeDay;

  /// No description provided for @themeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get themeNight;

  /// No description provided for @themeSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get themeSepia;

  /// No description provided for @layoutMode.
  ///
  /// In en, this message translates to:
  /// **'Layout mode'**
  String get layoutMode;

  /// No description provided for @layoutPaged.
  ///
  /// In en, this message translates to:
  /// **'Paged'**
  String get layoutPaged;

  /// No description provided for @layoutScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get layoutScroll;

  /// No description provided for @layoutDetails.
  ///
  /// In en, this message translates to:
  /// **'Typography details'**
  String get layoutDetails;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @lineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get lineHeight;

  /// No description provided for @pageGap.
  ///
  /// In en, this message translates to:
  /// **'Page gap'**
  String get pageGap;

  /// No description provided for @horizontalPadding.
  ///
  /// In en, this message translates to:
  /// **'Horizontal padding'**
  String get horizontalPadding;

  /// No description provided for @verticalPadding.
  ///
  /// In en, this message translates to:
  /// **'Vertical padding'**
  String get verticalPadding;

  /// No description provided for @enableTextIndent.
  ///
  /// In en, this message translates to:
  /// **'Enable first-line indent'**
  String get enableTextIndent;

  /// No description provided for @indentSizeEm.
  ///
  /// In en, this message translates to:
  /// **'Indent size (em)'**
  String get indentSizeEm;

  /// No description provided for @skipFirstParagraphIndent.
  ///
  /// In en, this message translates to:
  /// **'Skip first paragraph indent'**
  String get skipFirstParagraphIndent;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @searchInBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Search in book'**
  String get searchInBookTitle;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// No description provided for @imageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get imageLoadFailed;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @switchToNight.
  ///
  /// In en, this message translates to:
  /// **'Switch to night'**
  String get switchToNight;

  /// No description provided for @switchToDay.
  ///
  /// In en, this message translates to:
  /// **'Switch to day'**
  String get switchToDay;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @quickSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick settings'**
  String get quickSettingsTitle;

  /// No description provided for @recentlyOpenedBooks.
  ///
  /// In en, this message translates to:
  /// **'Recently opened books'**
  String get recentlyOpenedBooks;

  /// No description provided for @weeklyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading report'**
  String get weeklyReportTitle;

  /// No description provided for @statsTotalBooks.
  ///
  /// In en, this message translates to:
  /// **'Books in library'**
  String get statsTotalBooks;

  /// No description provided for @statsInProgressBooks.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statsInProgressBooks;

  /// No description provided for @statsCompletedBooks.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statsCompletedBooks;

  /// No description provided for @statsNotStartedBooks.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statsNotStartedBooks;

  /// No description provided for @statsAverageProgress.
  ///
  /// In en, this message translates to:
  /// **'Average progress'**
  String get statsAverageProgress;

  /// No description provided for @statsOpenedIn7Days.
  ///
  /// In en, this message translates to:
  /// **'Opened in 7 days'**
  String get statsOpenedIn7Days;

  /// No description provided for @statsImportedIn7Days.
  ///
  /// In en, this message translates to:
  /// **'Imported in 7 days'**
  String get statsImportedIn7Days;

  /// No description provided for @statsAnnotationsTotal.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get statsAnnotationsTotal;

  /// No description provided for @statsLatestOpened.
  ///
  /// In en, this message translates to:
  /// **'Latest opened'**
  String get statsLatestOpened;

  /// No description provided for @statsHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get statsHighlights;

  /// No description provided for @statsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get statsNotes;

  /// No description provided for @statsBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get statsBookmarks;

  /// No description provided for @statsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get statsNotAvailable;

  /// No description provided for @collectionsForBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections · {title}'**
  String collectionsForBookTitle(Object title);

  /// No description provided for @booksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} books'**
  String booksCount(int count);

  /// No description provided for @deleteSelectedBooksMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected books? This action cannot be undone.'**
  String deleteSelectedBooksMessage(int count);

  /// No description provided for @selectedBooksCount.
  ///
  /// In en, this message translates to:
  /// **'Selected books: {count}'**
  String selectedBooksCount(int count);

  /// No description provided for @recentReadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Last opened · {progress}%'**
  String recentReadingProgress(Object progress);

  /// No description provided for @readingProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress: {progress}%'**
  String readingProgress(Object progress);

  /// No description provided for @meStatsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats: {error}'**
  String meStatsLoadFailed(Object error);

  /// No description provided for @tocPageComingSoon.
  ///
  /// In en, this message translates to:
  /// **'TOC page is under development\\nbookUid={bookUid}'**
  String tocPageComingSoon(Object bookUid);

  /// No description provided for @searchInBookComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Search page is under development\\nbookUid={bookUid}'**
  String searchInBookComingSoon(Object bookUid);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
