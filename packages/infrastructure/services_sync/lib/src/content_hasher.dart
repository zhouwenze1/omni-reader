import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:foundation_domain/domain.dart';

/// 计算阅读位置的内容指纹。
///
/// 时间字段不属于阅读位置,因此不会参与指纹。
String readingProgressContentHash(ReadingProgress progress) {
  final canonical = _canonicalize(<String, dynamic>{
    'locator': progress.locator.toJson(),
    'progression': progress.progression,
  });
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final entries = <String, dynamic>{
      for (final key in value.keys) '$key': value[key],
    };
    final keys = entries.keys.toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalize(entries[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList();
  }
  if (value is num) {
    final doubleValue = value.toDouble();
    if (doubleValue.isFinite && doubleValue == doubleValue.truncateToDouble()) {
      return doubleValue.toInt();
    }
    return doubleValue;
  }
  return value;
}
