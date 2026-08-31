import 'package:foundation_domain/domain.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import 'db/app_database.dart';
import 'db/collection_dao.dart';
import 'db/library_index_dao.dart';
import 'db/reading_stats_dao.dart';
import 'repositories/annotation_repository_impl.dart';
import 'repositories/book_repository_impl.dart';
import 'repositories/collection_repository_impl.dart';
import 'repositories/import_repository_impl.dart';
import 'repositories/progress_repository_impl.dart';
import 'repositories/reading_stats_repository_impl.dart';
import 'repositories/settings_repository_impl.dart';
import 'repositories/toc_repository_impl.dart';
import 'services/file_service_impl.dart';
import 'services/fingerprint_service_impl.dart';
import 'services/import_conversion_stubs.dart';
import 'services/storage_paths.dart';
import 'services/cover_extraction_service.dart';

class DataModule {
  DataModule._({
    required this.storagePaths,
    required this.fileService,
    required this.fingerprintService,
    required this.database,
    required this.bookRepository,
    required this.progressRepository,
    required this.tocRepository,
    required this.annotationRepository,
    required this.collectionRepository,
    required this.settingsRepository,
    required this.importRepository,
    required this.readingStatsRepository,
    required this.settingsBox,
  });

  final StoragePaths storagePaths;
  final FileService fileService;
  final FingerprintService fingerprintService;
  final AppDatabase database;

  final BookRepository bookRepository;
  final ProgressRepository progressRepository;
  final TocRepository tocRepository;
  final AnnotationRepository annotationRepository;
  final CollectionRepository collectionRepository;
  final SettingsRepository settingsRepository;
  final ImportRepository importRepository;
  final ReadingStatsRepository readingStatsRepository;

  /// 全局 Hive 设置盒(同步配置等共享键值复用)。
  final Box<dynamic> settingsBox;

  static bool _hiveInited = false;

  static Future<DataModule> bootstrap({
    required StoragePaths storagePaths,
    required BookImportPort epubImportPort,
    required BookStoragePort bookStoragePort,
  }) async {
    final fileService = FileServiceImpl();
    final fingerprintService = FingerprintServiceImpl();

    final database = await AppDatabase.open(
      p.join(storagePaths.baseDir.path, 'reader.sqlite'),
    );

    final libraryIndexDao = LibraryIndexDao(database);
    final collectionDao = CollectionDao(database);
    final readingStatsDao = ReadingStatsDao(database);

    if (!_hiveInited) {
      Hive.init(storagePaths.baseDir.path);
      _hiveInited = true;
    }
    final settingsBox = await Hive.openBox<dynamic>('settings_box');

    final bookRepository = BookRepositoryImpl(
      storagePaths: storagePaths,
      fileService: fileService,
      libraryIndexDao: libraryIndexDao,
    );
    final progressRepository = ProgressRepositoryImpl(
      storagePaths: storagePaths,
      fileService: fileService,
      libraryIndexDao: libraryIndexDao,
    );
    final tocRepository = TocRepositoryImpl(
      storagePaths: storagePaths,
      fileService: fileService,
    );
    final annotationRepository = AnnotationRepositoryImpl(
      storagePaths: storagePaths,
      fileService: fileService,
    );
    final collectionRepository = CollectionRepositoryImpl(collectionDao);
    final readingStatsRepository = ReadingStatsRepositoryImpl(readingStatsDao);
    final settingsRepository = SettingsRepositoryImpl(settingsBox);
    final coverExtractionService = CoverExtractionService(
      storagePaths: storagePaths,
    );

    final importRepository = ImportRepositoryImpl(
      storagePaths: storagePaths,
      fileService: fileService,
      fingerprintService: fingerprintService,
      bookRepository: bookRepository,
      progressRepository: progressRepository,
      pdfPackager: StubPdfPackager(),
      audiobookConverter: StubLpfToAudiobookConverter(),
      epubImportPort: epubImportPort,
      bookStoragePort: bookStoragePort,
      coverExtractionService: coverExtractionService,
    );

    return DataModule._(
      storagePaths: storagePaths,
      fileService: fileService,
      fingerprintService: fingerprintService,
      database: database,
      bookRepository: bookRepository,
      progressRepository: progressRepository,
      tocRepository: tocRepository,
      annotationRepository: annotationRepository,
      collectionRepository: collectionRepository,
      settingsRepository: settingsRepository,
      importRepository: importRepository,
      readingStatsRepository: readingStatsRepository,
      settingsBox: settingsBox,
    );
  }
}
