import 'package:flutter/widgets.dart';

class MobileStrings {
  const MobileStrings();

  String get appTitle => 'Reader Mobile';
}

extension MobileL10nX on BuildContext {
  MobileStrings get l10n => const MobileStrings();
}
