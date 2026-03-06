import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';

final mobileBookDetailProvider =
    FutureProvider.family<Book?, String>((ref, bookUid) {
  return ref.watch(bookRepositoryProvider).getBook(bookUid);
});
