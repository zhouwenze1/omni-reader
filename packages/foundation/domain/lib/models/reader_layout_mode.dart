class ReaderLayoutMode {
  const ReaderLayoutMode._();

  static const String pagedAuto = 'paged_auto';
  static const String pagedSingle = 'paged_single';
  static const String pagedSpread = 'paged_spread';
  static const String scrollContinuous = 'scroll_continuous';
  static const String scrollBoundary = 'scroll_boundary';

  static const double compactLayoutBreakpoint = 600;

  static const Set<String> supportedValues = <String>{
    pagedAuto,
    pagedSingle,
    pagedSpread,
    scrollContinuous,
    scrollBoundary,
  };

  static String normalize(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'paged':
      case pagedAuto:
        return pagedAuto;
      case pagedSingle:
        return pagedSingle;
      case pagedSpread:
        return pagedSpread;
      case 'scroll':
      case scrollBoundary:
        return scrollBoundary;
      case scrollContinuous:
        return scrollContinuous;
      default:
        return pagedAuto;
    }
  }

  static String normalizeRendererMode(String? value) {
    final normalized = normalize(value);
    if (normalized == pagedAuto) {
      return pagedSingle;
    }
    return normalized;
  }

  static bool prefersSinglePage(
    double shortestSide, {
    double breakpoint = compactLayoutBreakpoint,
  }) {
    return shortestSide < breakpoint;
  }

  static String resolveAdaptive(
    String? layoutMode, {
    required double shortestSide,
    double breakpoint = compactLayoutBreakpoint,
  }) {
    final normalized = normalize(layoutMode);
    if (normalized != pagedAuto) {
      return normalized;
    }
    return prefersSinglePage(shortestSide, breakpoint: breakpoint)
        ? pagedSingle
        : pagedSpread;
  }
}
