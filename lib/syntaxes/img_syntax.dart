import 'package:markdown/markdown.dart' as md;

class ImgInlineSyntax extends md.InlineSyntax {
  static const String stringPattern = r'<img (src="[a-zA-Z-./_0-9]+".*)/>';
  static const String xtringPattern = r'<img src="([a-zA-Z-./_0-9]+)"(?: *width="([0-9]+)"(?: +height="([0-9]+)")?)? */>';

  @override
  // ignore: overridden_fields
  final pattern = RegExp(stringPattern);

  ImgInlineSyntax()
      : super(
          r'<img',
          startCharacter: '<'.codeUnitAt(0),
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // RegExpMatch m = pattern.firstMatch(parser.source)!;
    final element = parseInlineImage(match[1]!);
    parser.addNode(element);

    parser.consume(match[0]!.length);
    return false;
  }

  static md.Node parseInlineImage(String attributes) {
    final regexpSrc = RegExp('src="([a-zA-Z-./_0-9]+)"');
    final regexpColor = RegExp(r'color\s*:\s*(#[0-9a-fA-F]{6})');
    final regexpWidth = RegExp('width="([0-9]+)"');
    final regexpHeight = RegExp('height="([0-9]+)"');

    final src = regexpSrc.firstMatch(attributes)![1]!;
    final hexColorMatch = regexpColor.firstMatch(attributes);
    final widthMatch = regexpWidth.firstMatch(attributes);
    final heightMatch = regexpHeight.firstMatch(attributes);

    String size = '';
    if (heightMatch != null) {
      size = '#${widthMatch![1]!}x${heightMatch[1]!}';
    } else if (widthMatch != null) {
      size = '#${widthMatch[1]}';
    }

    final element = md.Element.empty('img');
    element.attributes['src'] = '$src$size';
    if (hexColorMatch != null) element.attributes['color'] = hexColorMatch[1]!;

    return element;
  }
}

class ImgBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp('^\\s*${ImgInlineSyntax.stringPattern}\\s*\$');

  @override
  md.Node? parse(md.BlockParser parser) {
    RegExpMatch m = pattern.firstMatch(parser.current)!;
    final element = ImgInlineSyntax.parseInlineImage(m[1]!);

    parser.advance();
    return element;
  }
}
