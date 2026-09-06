import 'package:flutter_riverpod/flutter_riverpod.dart';

final readerCurrentHrefProvider = StateProvider.family<String?, String>(
  (ref, bookUid) => null,
);
