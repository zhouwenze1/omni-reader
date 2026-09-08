import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'mobi_container.dart';

/// 清洗 mobipocket HTML 并把整本按 `<mbp:pagebreak>` 切成章节。
///
/// 输入 [MobiBook.rawHtml](未清洗,mobipocket 专有),输出 N 个相对干净的
/// XHTML 片段(不含 `<html>`/`<head>`,只有 `<body>` 内内容),供上层拼成章节
/// 文件并作为 spine。
///
/// 切分在"文本层"做(先用正则把 pagebreak 换成不可见占位再按占位切),
/// 不依赖 html 解析器的结构——mobipocket HTML 常有未闭合标签,html 解析
/// 会把后续 pagebreak 吞进深层,顶层切分会漏。
class MobiCleaner {
  const MobiCleaner();

  /// 把整本 rawHtml 解码 + 清洗 + 切分成章节 body 片段。
  ///
  /// [imagePathOf] 把 recindex(1-based 资源序号)映射为图片目标相对路径
  /// (如 '../Images/img0001.jpeg');返回 null 表示跳过该图。
  List<String> cleanAndSplit(
    List<int> rawHtmlBytes,
    int codepage, {
    required String? Function(int recindex) imagePathOf,
  }) {
    var html = decodeMobiText(rawHtmlBytes, codepage);
    // 1. 文本层按 pagebreak 切段(先换占位,避免标签形态差异)。
    final pieces = _splitOnPageBreaks(html);
    final result = <String>[];
    for (var piece in pieces) {
      piece = piece.trim();
      if (piece.isEmpty) {
        continue;
      }
      // 2. 每段独立清洗(包一层文档解析,容错乱标签)。
      final cleaned = _cleanPiece(piece, imagePathOf);
      // 3. 清洗后可能变空(如纯 <mbp:pagebreak> 的壳段):丢弃。
      //    "空"= 无文本且无可见元素(img/svg 等算可见)。
      final textOnly = cleaned.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      final hasMedia = RegExp(
        r'<(img|svg|video|audio)\b',
        caseSensitive: false,
      ).hasMatch(cleaned);
      if (textOnly.isEmpty && !hasMedia) {
        continue;
      }
      result.add(cleaned);
    }
    return result;
  }

  /// 把 [raw] 按 `<mbp:pagebreak>` 切成若干文本段(不含断点)。
  List<String> _splitOnPageBreaks(String raw) {
    final pattern = RegExp(
      r'<\s*mbp:pagebreak[^>]*>\s*<\s*/mbp:pagebreak\s*>'
      r'|<\s*mbp:pagebreak\s*/?>'
      r'|<\s*mbp:pagebreak\s*>',
      caseSensitive: false,
    );
    return raw.split(pattern);
  }

  /// 清洗单段:DOM 解析 → 删专有/guide/recindex 图/font 归一 → 序列化 body。
  String _cleanPiece(String piece, String? Function(int) imagePathOf) {
    // mobipocket 段常无 <html><body>;包一层完整文档让 html 解析。
    final wrapped = '<html><body>$piece</body></html>';
    final document = html_parser.parse(wrapped);
    final body = document.body;
    if (body == null) {
      return piece;
    }
    _cleanElementTree(body, imagePathOf);
    final buffer = StringBuffer();
    for (final node in body.nodes) {
      _writeNode(buffer, node);
    }
    return buffer.toString().trim();
  }

  void _cleanElementTree(dom.Element root, String? Function(int) imagePathOf) {
    // 后序遍历:先清子树再处理本节点,便于 remove 后不跳过兄弟。
    final children = List<dom.Node>.of(root.nodes);
    for (final child in children) {
      if (child is dom.Element) {
        _cleanElementTree(child, imagePathOf);
      }
    }
    _cleanElement(root, imagePathOf);
  }

  void _cleanElement(dom.Element el, String? Function(int) imagePathOf) {
    final tag = el.localName?.toLowerCase() ?? '';
    // mobipocket 专有 / 非内容结构:删。
    if (tag.startsWith('mbp:') ||
        tag == 'guide' ||
        tag == 'ncx' ||
        tag == 'reference') {
      el.remove();
      return;
    }
    if (tag == 'font') {
      _convertFont(el);
      return;
    }
    if (tag == 'img') {
      _fixImage(el, imagePathOf);
      return;
    }
  }

  void _convertFont(dom.Element font) {
    final style = StringBuffer();
    final face = font.attributes['face'];
    if (face != null && face.isNotEmpty) {
      style.write('font-family: "$face"; ');
    }
    final size = font.attributes['size'];
    if (size != null) {
      final em = _fontSizeToEm(size);
      if (em != null) {
        style.write('font-size: ${em}em; ');
      }
    }
    final span = dom.Element.tag('span');
    final s = style.toString().trim();
    if (s.isNotEmpty) {
      span.attributes['style'] = s;
    }
    final parent = font.parent;
    if (parent == null) {
      return;
    }
    final idx = parent.nodes.indexOf(font);
    final kids = List<dom.Node>.of(font.nodes);
    font.nodes.clear();
    for (final k in kids) {
      span.append(k);
    }
    parent.nodes[idx] = span;
  }

  void _fixImage(dom.Element img, String? Function(int) imagePathOf) {
    final raw =
        img.attributes['recindex'] ??
        img.attributes['lowrecindex'] ??
        img.attributes['hirecindex'];
    final rec = raw == null ? null : int.tryParse(raw.trim());
    if (rec == null || rec <= 0) {
      return;
    }
    final path = imagePathOf(rec);
    if (path == null) {
      return;
    }
    img.attributes.remove('recindex');
    img.attributes.remove('lowrecindex');
    img.attributes.remove('hirecindex');
    img.attributes['src'] = path;
  }

  void _writeNode(StringBuffer buffer, dom.Node node) {
    if (node is dom.Element) {
      buffer.write(node.outerHtml);
    } else if (node is dom.Text) {
      buffer.write(node.text);
    } else if (node is dom.Comment) {
      buffer.write('<!--${node.data}-->');
    }
  }

  static double? _fontSizeToEm(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null) {
      return null;
    }
    const table = <double>[0.65, 0.8, 1.0, 1.2, 1.44, 1.73, 2.0];
    if (v >= 1 && v <= 7) {
      return table[v - 1];
    }
    return null;
  }
}
