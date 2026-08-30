import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';

import 'book_uri_mapper.dart';

class RendererHighlightMapper {
  const RendererHighlightMapper();

  Map<String, dynamic> toPayload(
    ReaderHighlight highlight, {
    BookUriMapper? uriMapper,
  }) {
    final href = uriMapper?.toPublicHref(highlight.href) ??
        highlight.href.trim().replaceAll('\\', '/').replaceFirst(
              RegExp(r'^/+'),
              '',
            );

    return <String, dynamic>{
      'uid': highlight.uid,
      'href': href,
      'color': highlight.color,
      'anchor': <String, dynamic>{
        'text': highlight.quote.toJson(),
        if (highlight.cfi != null && highlight.cfi!.isNotEmpty)
          'cfi': highlight.cfi,
      },
    };
  }

  ReaderTextQuote? quoteFromLocator(Locator locator) {
    final anchor = locator.anchor;
    final text = anchor?['text'];
    if (text == null) {
      return null;
    }
    final quote = ReaderTextQuote.fromJson(text);
    return quote.isUsable ? quote : null;
  }
}
