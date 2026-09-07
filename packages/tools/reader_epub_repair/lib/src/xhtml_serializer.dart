import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _xhtmlNamespace = 'http://www.w3.org/1999/xhtml';
const _epubNamespace = 'http://www.idpf.org/2007/ops';
const _xlinkNamespace = 'http://www.w3.org/1999/xlink';
const _xmlNamespace = 'http://www.w3.org/XML/1998/namespace';

const _htmlVoidElements = <String>{
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

String repairMalformedXhtml(String source, {String? version}) {
  final parser = html_parser.HtmlParser(
    source,
    lowercaseElementName: false,
    lowercaseAttrName: false,
  );
  final document = parser.parse();
  final root = document.documentElement;
  if (root == null) {
    throw const FormatException('Malformed XHTML has no document element');
  }
  return serializeDomAsXml(root, xhtmlRoot: true, version: version);
}

String repairMalformedXmlLike(String source, {required String expectedRoot}) {
  final parser = html_parser.HtmlParser(
    source,
    lowercaseElementName: false,
    lowercaseAttrName: false,
  );
  final document = parser.parse();
  final candidates = document.querySelectorAll(expectedRoot);
  final root = candidates.isNotEmpty
      ? candidates.first
      : document.documentElement;
  if (root == null ||
      root.localName?.toLowerCase() != expectedRoot.toLowerCase()) {
    throw FormatException('Expected <$expectedRoot> in malformed XML');
  }
  return serializeDomAsXml(root, xhtmlRoot: expectedRoot == 'html');
}

String serializeDomAsXml(
  dom.Element root, {
  required bool xhtmlRoot,
  String? version,
}) {
  final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>');
  if (xhtmlRoot) {
    final doctype = version?.startsWith('2') == true
        ? '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" '
              '"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
        : '<!DOCTYPE html>';
    buffer.write('\n$doctype');
  }
  buffer.write('\n');
  _writeElement(buffer, root, isRoot: true, xhtmlRoot: xhtmlRoot);
  return buffer.toString();
}

void _writeElement(
  StringBuffer output,
  dom.Element element, {
  required bool isRoot,
  required bool xhtmlRoot,
}) {
  final tag = element.localName ?? 'div';
  output.write('<$tag');

  final attributes = <String, String>{};
  for (final entry in element.attributes.entries) {
    attributes['${entry.key}'] = entry.value;
  }

  if (isRoot) {
    if (xhtmlRoot && !attributes.containsKey('xmlns')) {
      attributes['xmlns'] = _xhtmlNamespace;
    }
    if (_containsAttributePrefix(element, 'epub:') &&
        !attributes.containsKey('xmlns:epub')) {
      attributes['xmlns:epub'] = _epubNamespace;
    }
    if (_containsAttributePrefix(element, 'xlink:') &&
        !attributes.containsKey('xmlns:xlink')) {
      attributes['xmlns:xlink'] = _xlinkNamespace;
    }
    if (_containsAttributePrefix(element, 'xml:') &&
        !attributes.containsKey('xmlns:xml')) {
      attributes['xmlns:xml'] = _xmlNamespace;
    }
  }

  for (final entry in attributes.entries) {
    output
      ..write(' ')
      ..write(entry.key)
      ..write('="')
      ..write(_escapeAttribute(entry.value))
      ..write('"');
  }

  final isSvg =
      element.namespaceUri == 'http://www.w3.org/2000/svg' ||
      tag.toLowerCase() == 'svg';
  if (element.nodes.isEmpty) {
    if ((!isSvg && _htmlVoidElements.contains(tag.toLowerCase())) || isSvg) {
      output.write(' />');
    } else {
      output
        ..write('></')
        ..write(tag)
        ..write('>');
    }
    return;
  }

  output.write('>');
  for (final node in element.nodes) {
    if (node is dom.Element) {
      _writeElement(output, node, isRoot: false, xhtmlRoot: xhtmlRoot);
    } else if (node is dom.Text) {
      output.write(_escapeText(node.data));
    } else if (node is dom.Comment) {
      final comment = (node.data ?? '').replaceAll('--', '- -');
      output.write('<!--$comment-->');
    }
  }
  output
    ..write('</')
    ..write(tag)
    ..write('>');
}

bool _containsAttributePrefix(dom.Element root, String prefix) {
  for (final element in root.querySelectorAll('*')) {
    for (final attribute in element.attributes.keys) {
      if ('$attribute'.toLowerCase().startsWith(prefix)) {
        return true;
      }
    }
  }
  for (final attribute in root.attributes.keys) {
    if ('$attribute'.toLowerCase().startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

String _escapeText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttribute(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('"', '&quot;');
