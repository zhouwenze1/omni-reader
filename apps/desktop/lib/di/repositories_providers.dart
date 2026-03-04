import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import 'providers.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return ref.watch(dataModuleProvider).bookRepository;
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ref.watch(dataModuleProvider).progressRepository;
});

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return ref.watch(dataModuleProvider).importRepository;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return ref.watch(dataModuleProvider).settingsRepository;
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return ref.watch(dataModuleProvider).collectionRepository;
});

final annotationRepositoryProvider = Provider<AnnotationRepository>((ref) {
  return ref.watch(dataModuleProvider).annotationRepository;
});
