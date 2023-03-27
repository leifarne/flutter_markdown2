import 'package:markdown/markdown.dart' as md;

/// Requires <thead> and <tbody>
///
class TableHtmlSyntax extends md.BlockSyntax {
  static const _openstring = '<table.*>';
  static const _closestring = '</table>';

  /// The line contains only whitespace or is empty.
  final emptyPattern = RegExp(r'^(?:[ \t]*)$');

  int _pos = 0;
  final List<String> _childLines = [];

  @override
  RegExp get pattern => RegExp(_openstring);

  RegExp get _endPattern => RegExp(_closestring);

  @override
  md.Node? parse(md.BlockParser parser) {
    // Collect the style=color attribute, which we will use as the table header color.
    int? color = _parseStyle(parser.current);

    // Eat the <table> tag.
    parser.advance();

    // Eat until we hit _endPattern.
    while (!parser.isDone && !parser.matches(_endPattern)) {
      _childLines.add(parser.current);
      parser.advance();
    }

    // Eat the ending </table> tag
    parser.advance();

    // Parse table content
    _pos = 0;

    md.Element thead = _parseTableBlocks('thead', 'th', color);
    md.Element tbody = _parseTableBlocks('tbody', 'td');

    // Check that all rows have the same length as the header row.
    final length = (thead.children!.single as md.Element).children!.length;
    if (tbody.children!.any((row) => (row as md.Element).children!.length != length)) {
      throw ArgumentError.value(length, '_childLines', 'All table rows should have equal length');
    }

    // Create and return the entire table element
    return md.Element('table', [
      thead,
      tbody,
    ]);
  }

  /// Check if we are done with the table contents
  ///
  bool get done => _pos >= _childLines.length;

  /// Parse <thead> and <tbody> in _childLines.
  ///
  md.Element _parseTableBlocks(String block, String cell, [int? color]) {
    // fast forward
    //
    void skipBlankLines() {
      while (!done && emptyPattern.hasMatch(_childLines[_pos])) {
        _pos++;
      }
      if (done) throw ArgumentError.value('<tr>', 'childLines', 'is missing');
    }

    //
    // Closing tag is not on this line, so continue to add lines to the cell
    // until we find the closing tag.
    //
    String processCellLinesForOneCell(String cellTag) {
      final cellLines = <String>[];

      // Collect the fragment from the line with the opening tag.
      final matchFirstFragment = RegExp('\\s*<$cellTag>(.*)').firstMatch(_childLines[_pos])!;
      cellLines.add(matchFirstFragment[1]!);
      _pos++;

      while (!done && !RegExp('</$cellTag>').hasMatch(_childLines[_pos])) {
        // Collect the text lines for the cell
        cellLines.add(_childLines[_pos].trim());
        _pos++; // eat text line
      }
      if (done) throw ArgumentError.value('</$cellTag>', 'childLines', 'is missing');

      // We have reached the line with the closing tag.
      final beginningOfLine = RegExp('(.*)</$cellTag>').firstMatch(_childLines[_pos]);
      cellLines.add(beginningOfLine?[1]?.trim() ?? '');

      // Join all the text lines in a cell
      // If more tags on one line, need a pos counter. Or matchAll
      // Either multiline, or more tags on one line, only.

      return cellLines.where((e) => e.isNotEmpty).join(' ').trim();
    }

    //
    // Is the </td> tag on this line? If yes, it is a oneliner.
    //
    List<String> processCellsFromOneLine(String cellTag) {
      final allMatches = RegExp('\\s*<$cellTag>(.*?)</$cellTag>').allMatches(_childLines[_pos]);

      assert(allMatches.isNotEmpty); // && matches[0][2] != null);

      final cells = <String>[];

      for (var match in allMatches) {
        // Collect whatever cell content we found on this line.
        cells.add(match[1]!.trim());
      }

      return cells;
    }

    // Main function body.
    //
    // For the child lines, parse <td> nodes.
    // If it matches td, parse td, which is a block or inline element
    // while parser does not match </td>, eat child lines.

    // Scan forward until the block ('thead' or 'tbody') is found.
    while (!done && !RegExp('<$block>').hasMatch(_childLines[_pos])) {
      _pos++;
    }
    if (done) throw ArgumentError.value('<$block>', 'childLines', 'is missing');

    final rows = <List<String>>[];
    if (RegExp('<$block>').hasMatch(_childLines[_pos])) {
      _pos++; // eat tbody

      while (!RegExp('</$block>').hasMatch(_childLines[_pos])) {
        skipBlankLines();

        if (RegExp('<tr>').hasMatch(_childLines[_pos])) {
          _pos++; // eat tr

          // Find the cells between <tr> and </tr>
          final cells = <String>[];
          while (!RegExp('</tr>').hasMatch(_childLines[_pos])) {
            skipBlankLines();

            // Check if we have an opening cell tag.
            if (RegExp('<$cell>').hasMatch(_childLines[_pos])) {
              // Collect the rest of the td-line, with or without the </td> tag.
              final matchesEndTag = RegExp('</$cell>').hasMatch(_childLines[_pos]);
              if (matchesEndTag) {
                // Tags here. Take everything from this line. Many cells.
                cells.addAll(processCellsFromOneLine(cell));
              } else {
                // No end tag here. Collect all cell lines until end tag. Single cell.
                cells.add(processCellLinesForOneCell(cell));
              }

              _pos++; // eat </td>
            } else {
              throw ArgumentError.value('<$cell>', _childLines[_pos], 'expected');
            }
          }
          rows.add(cells);
          _pos++; // eat </tr>
        }
      }

      _pos++; // eat </tbody>
    }

    return _createTableElement(block, cell, rows, color);
  }

  md.Element _createTableElement(String blockTag, String cellTag, List<List<String>> rows, int? color) {
    // Lag tbody (eller thead)
    final blockElement = md.Element(blockTag, <md.Element>[]);

    for (var row in rows) {
      // Lag ny rad
      final tr = md.Element('tr', <md.Element>[]);

      // Add cells to row - th or td
      for (var cellText in row) {
        final element = md.Element(cellTag, [md.UnparsedContent(cellText)]);
        if (color != null) {
          element.attributes['color'] = '$color';
        }
        tr.children!.add(element);
      }

      // Legg til rader på tbody (eller thead)
      blockElement.children!.add(tr);
    }
    return blockElement;
  }

  @override
  List<String?> parseChildLines(md.BlockParser parser) {
    final children = <String>[];
    for (int i = 0; i < 2; i++) {
      children.add(parser.current);
      parser.advance();
    }
    return children;
  }

  int? _parseStyle(String current) {
    final styleMatch = RegExp(r'style="(.*)"').firstMatch(current);
    if (styleMatch == null) return null;

    final styles = styleMatch[1]!;
    final colorMatch = RegExp(r'color\s*:\s*#([0-9a-fA-F]{6})').firstMatch(styles)!;
    final color = int.tryParse(colorMatch[1]!, radix: 16);

    return color;
  }
}
