import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:infrastructure_data/data.dart';

import 'repositories_providers.dart';

final dataModuleProvider = Provider<DataModule>((ref) {
  throw UnimplementedError(
      'dataModuleProvider must be overridden in bootstrap');
});

final libraryIndexProvider = FutureProvider<List<LibraryIndexEntry>>((ref) {
  return ref.watch(bookRepositoryProvider).listLibraryIndex();
});

/// 是否处于阅读页(由 ReaderPage 生命周期驱动,用于隐藏应用顶部标题栏)。
final readerActiveProvider = StateProvider<bool>((ref) => false);
