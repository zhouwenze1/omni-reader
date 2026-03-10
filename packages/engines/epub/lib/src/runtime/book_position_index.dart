import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;

import 'book_storage_service.dart';

class BookPositionIndex {
  const BookPositionIndex._({
    required List<_BookPositionPoint> allPoints,
    required Map<String, List<_BookPositionPoint>> pointsByHref,
  })  : _allPoints = allPoints,
        _pointsByHref = pointsByHref;

  final List<_BookPositionPoint> _allPoints;
  final Map<String, List<_BookPositionPoint>> _pointsByHref;

  bool get isEmpty => _allPoints.isEmpty;

  static Future<BookPositionIndex?> load({
    required BookStorageService storageService,
    required String bookUuid,
  }) async {
    final document = await storageService.readPositionsDocument(bookUuid);
    if (document == null || document.isEmpty) {
      return null;
    }

    final rawPositions = document['positions'];
    if (rawPositions is! List) {
      return null;
    }

    final allPoints = <_BookPositionPoint>[];
    final pointsByHref = <String, List<_BookPositionPoint>>{};

    for (final rawEntry in rawPositions) {
      final entry = _asMap(rawEntry);
      final locations = _asMap(entry?['locations']);
      final href = _normalizeHref(entry?['href']);
      final progression = _asDouble(locations?['progression']);
      final totalProgression = _asDouble(locations?['totalProgression']);
      if (href == null || progression == null || totalProgression == null) {
        continue;
      }

      final point = _BookPositionPoint(
        href: href,
        progression: progression.clamp(0.0, 1.0),
        totalProgression: totalProgression.clamp(0.0, 1.0),
      );
      allPoints.add(point);
      pointsByHref.putIfAbsent(href, () => <_BookPositionPoint>[]).add(point);
    }

    if (allPoints.isEmpty) {
      return null;
    }

    allPoints.sort(
      (left, right) => left.totalProgression.compareTo(right.totalProgression),
    );
    for (final points in pointsByHref.values) {
      points.sort(
        (left, right) => left.progression.compareTo(right.progression),
      );
    }

    return BookPositionIndex._(
      allPoints: allPoints,
      pointsByHref: pointsByHref,
    );
  }

  double? resolveTotalProgressionForLocator(Locator locator) {
    final explicitTotal = _asDouble(locator.locations?['totalProgression']);
    if (explicitTotal != null) {
      return explicitTotal.clamp(0.0, 1.0);
    }

    final progression = _asDouble(locator.locations?['progression']);
    if (progression == null) {
      return null;
    }

    final href = _normalizeHref(locator.href ?? locator.url);
    if (href == null) {
      return progression.clamp(0.0, 1.0);
    }

    final points = _pointsByHref[href];
    if (points == null || points.isEmpty) {
      return progression.clamp(0.0, 1.0);
    }
    return _resolveTotalProgressionForHref(
      points,
      progression.clamp(0.0, 1.0),
    );
  }

  Locator? resolveLocatorForTotalProgression(double totalProgression) {
    if (_allPoints.isEmpty) {
      return null;
    }
    final point = _resolvePointForTotal(totalProgression.clamp(0.0, 1.0));
    return Locator(
      href: point.href,
      locations: <String, dynamic>{
        'progression': point.progression,
        'totalProgression': point.totalProgression,
      },
    );
  }

  double _resolveTotalProgressionForHref(
    List<_BookPositionPoint> points,
    double progression,
  ) {
    if (points.length == 1) {
      return points.first.totalProgression;
    }

    final upperIndex = _lowerBoundByProgression(points, progression);
    if (upperIndex <= 0) {
      return points.first.totalProgression;
    }
    if (upperIndex >= points.length) {
      return points.last.totalProgression;
    }

    final lower = points[upperIndex - 1];
    final upper = points[upperIndex];
    if ((upper.progression - lower.progression).abs() < 1e-9) {
      return upper.totalProgression;
    }

    final ratio = (progression - lower.progression) /
        (upper.progression - lower.progression);
    final total = lower.totalProgression +
        ((upper.totalProgression - lower.totalProgression) * ratio);
    return total.clamp(0.0, 1.0);
  }

  _BookPositionPoint _resolvePointForTotal(double totalProgression) {
    if (_allPoints.length == 1) {
      return _allPoints.first;
    }

    final upperIndex =
        _lowerBoundByTotalProgression(_allPoints, totalProgression);
    if (upperIndex <= 0) {
      return _allPoints.first;
    }
    if (upperIndex >= _allPoints.length) {
      return _allPoints.last;
    }

    final lower = _allPoints[upperIndex - 1];
    final upper = _allPoints[upperIndex];
    if (lower.href == upper.href &&
        (upper.totalProgression - lower.totalProgression).abs() >= 1e-9) {
      final ratio = (totalProgression - lower.totalProgression) /
          (upper.totalProgression - lower.totalProgression);
      final progression =
          lower.progression + ((upper.progression - lower.progression) * ratio);
      return _BookPositionPoint(
        href: lower.href,
        progression: progression.clamp(0.0, 1.0),
        totalProgression: totalProgression,
      );
    }

    final lowerDelta = (totalProgression - lower.totalProgression).abs();
    final upperDelta = (upper.totalProgression - totalProgression).abs();
    return lowerDelta <= upperDelta ? lower : upper;
  }

  static int _lowerBoundByProgression(
    List<_BookPositionPoint> points,
    double progression,
  ) {
    var low = 0;
    var high = points.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (points[mid].progression < progression) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  static int _lowerBoundByTotalProgression(
    List<_BookPositionPoint> points,
    double totalProgression,
  ) {
    var low = 0;
    var high = points.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (points[mid].totalProgression < totalProgression) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry('$key', entryValue));
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static String? _normalizeHref(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    final path = uri == null ? trimmed : uri.path;
    final normalized = p.posix.normalize(path.replaceAll('\\', '/'));
    if (normalized.isEmpty || normalized == '.' || normalized == '/') {
      return null;
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }
}

class _BookPositionPoint {
  const _BookPositionPoint({
    required this.href,
    required this.progression,
    required this.totalProgression,
  });

  final String href;
  final double progression;
  final double totalProgression;
}
