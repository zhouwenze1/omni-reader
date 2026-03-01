class ParagraphSegmenter {
  const ParagraphSegmenter();

  List<String> segment(String input, {int minParagraphLength = 2}) {
    final plainText = stripHtml(input);
    final normalized = plainText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    final parts = normalized
        .split(RegExp(r'\n\s*\n+|\n'))
        .map((part) => part.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((part) => part.length >= minParagraphLength)
        .toList(growable: false);

    return parts;
  }

  String stripHtml(String input) {
    var text = input;

    text = text
        .replaceAll(
          RegExp(
            r'<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<style[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        );

    text = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</?(p|div|section|article|li|blockquote|h[1-6]|tr|td)[^>]*>',
            caseSensitive: false,
          ),
          '\n',
        );

    text = text.replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ');
    text = _decodeBasicHtmlEntities(text);

    return text;
  }

  String _decodeBasicHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
