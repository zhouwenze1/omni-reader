import 'dart:math' as math;

import 'package:kernel/kernel.dart';

class RendererStyleMapper {
  const RendererStyleMapper();

  Map<String, dynamic> toPayload(ReaderStyle style) {
    return <String, dynamic>{
      'theme': style.theme,
      'pageGap': style.pageGap,
      'fontSize': style.fontSize,
      'lineHeight': style.lineHeight,
      'paddingV': math.max(style.paddingTop, style.paddingBottom),
      'paddingH': math.max(style.paddingLeft, style.paddingRight),
      'textIndentEnabled': style.textIndentEnabled,
      'textIndentEm': style.textIndentEm,
      'textIndentSkipFirstParagraph': style.textIndentSkipFirstParagraph,
    };
  }
}
