import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories_providers.dart';

final importServiceProvider = Provider((ref) {
  return ref.watch(importRepositoryProvider);
});
