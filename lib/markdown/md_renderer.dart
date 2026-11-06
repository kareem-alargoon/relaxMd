import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/arabic_search.dart';
import '../core/direction.dart';
import '../core/themes.dart';

List<md.Node> parseMarkdown(String source) {
  final doc = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  return doc.parseLines(source.replaceAll('\r\n', '\n').split('\n'));
}

class HeadingInfo {
  const HeadingInfo(this.level, this.text, this.key, this.direction);

  final int level;
  final String text;
  final GlobalKey key;
  final TextDirection direction;
}

class RenderResult {
  const RenderResult(this.blocks, this.headings, this.matchKeys);

  final List<Widget> blocks;
  final List<HeadingInfo> headings;

  /// One key per search match (the key of the block holding it), in order.
  final List<GlobalKey> matchKeys;

  int get matchCount => matchKeys.length;
}

/// A piece of inline text with its style, or an inline widget (image).
class _Run {
  const _Run(this.text, this.style, {this.code = false, this.widget});

  final String text;
  final TextStyle style;
  final bool code;
  final Widget? widget;
}

/// Turns a Markdown AST into widgets. Every text block (paragraph, heading,
/// list item, table cell, quote) gets its own direction from [resolver], and
/// code always stays LTR. Use a new renderer for each build.
class MdRenderer {
  MdRenderer({
    required this.palette,
    required this.bodyStyle,
    required this.resolver,
    required this.documentDirection,
    this.applyFont = _identity,
    this.query = '',
    this.searchOptions = const SearchOptions(),
    this.currentMatch = -1,
    this.latinReadingOrder = true,
    List<GlobalKey>? keyPool,
  })  : _keyPool = keyPool ?? <GlobalKey>[],
        _base = bodyStyle;

  final ReaderPalette palette;

  /// Font size, line height and color of body text, without a font family.
  final TextStyle bodyStyle;

  /// Applies the reading font to a style (kept separate so bold text gets
  /// the real bold font instead of a synthesized one).
  final TextStyle Function(TextStyle) applyFont;
  final DirectionResolver resolver;

  /// Used for blocks with no letters, such as a line of numbers.
  final TextDirection documentDirection;
  final String query;
  final SearchOptions searchOptions;
  final int currentMatch;

  /// In RTL blocks, keeps English words separated by punctuation in reading
  /// order (see [DirectionResolver.latinBreaks]).
  final bool latinReadingOrder;

  /// Keys reused between builds so blocks keep their identity.
  final List<GlobalKey> _keyPool;
  int _keyIndex = 0;
  TextStyle _base;
  int _listDepth = 0;
  final List<HeadingInfo> _headings = [];
  final List<GlobalKey> _matchKeys = [];

  static TextStyle _identity(TextStyle s) => s;

  static const _blockTags = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'pre',
    'blockquote', 'hr', 'table', 'div', 'section',
  };

  double get _size => bodyStyle.fontSize ?? 18;

  TextStyle get _mono => TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Noto Sans Mono', 'Courier New'],
        fontSize: _size * 0.85,
        height: 1.5,
        color: palette.text,
      );

  RenderResult render(List<md.Node> nodes) {
    final blocks = _blockList(nodes);
    return RenderResult(blocks, _headings, _matchKeys);
  }

  GlobalKey _nextKey() {
    if (_keyIndex >= _keyPool.length) _keyPool.add(GlobalKey());
    return _keyPool[_keyIndex++];
  }

  List<Widget> _blockList(List<md.Node> nodes) {
    final out = <Widget>[];
    final inline = <md.Node>[];
    void flush() {
      if (inline.isEmpty) return;
      out.add(_textBlock(List.of(inline), _base));
      inline.clear();
    }

    for (final n in nodes) {
      if (n is md.Element && _blockTags.contains(n.tag)) {
        flush();
        out.add(_block(n));
      } else if (n is md.Text && n.text.trim().isEmpty && inline.isEmpty) {
        continue;
      } else {
        inline.add(n);
      }
    }
    flush();
    return out;
  }

  Widget _block(md.Element e) {
    final kids = e.children ?? const <md.Node>[];
    switch (e.tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final level = int.parse(e.tag.substring(1));
        return _textBlock(kids, _headingStyle(level), headingLevel: level);
      case 'p':
        return _textBlock(kids, _base);
      case 'pre':
        return _codeBlock(e);
      case 'blockquote':
        return _quote(e);
      case 'ul' || 'ol':
        return _list(e);
      case 'hr':
        return Padding(
          padding: EdgeInsets.symmetric(vertical: _size * 0.6),
          child: Divider(color: palette.line, thickness: 1, height: 1),
        );
      case 'table':
        return _table(e);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _blockList(kids),
        );
    }
  }

  TextStyle _headingStyle(int level) {
    const scales = [1.6, 1.4, 1.25, 1.12, 1.0, 0.95];
    return _base.copyWith(
      fontSize: _size * scales[level - 1],
      fontWeight: FontWeight.w700,
      height: 1.5,
      color: level <= 2 ? palette.accent : palette.text,
    );
  }

  double get _paragraphGap => _listDepth > 0 ? _size * 0.2 : _size * 0.6;

  /// Finds search matches in [plain] and records [key] once per match.
  (List<MatchRange>, int) _matchesFor(String plain, GlobalKey key) {
    if (query.trim().isEmpty) return (const [], 0);
    final matches = ArabicSearch.find(plain, query, searchOptions);
    final first = _matchKeys.length;
    for (var i = 0; i < matches.length; i++) {
      _matchKeys.add(key);
    }
    return (matches, first);
  }

  Widget _textBlock(List<md.Node> nodes, TextStyle style,
      {int? headingLevel, double? bottom}) {
    final runs = <_Run>[];
    _collect(nodes, style, runs);
    final plain = runs.map((r) => r.text).join();
    final dir = resolver.resolve(plain, fallback: documentDirection);
    final key = _nextKey();
    final (matches, first) = _matchesFor(plain, key);
    final fixOrder = latinReadingOrder && dir == TextDirection.rtl;
    // Search offsets are counted on [plain]; the marks go in only when the
    // spans are built.
    final breaks =
        fixOrder ? DirectionResolver.latinBreaks(plain) : const <int>{};
    if (headingLevel != null) {
      final title = plain.trim();
      _headings.add(HeadingInfo(headingLevel,
          fixOrder ? DirectionResolver.withLatinBreaks(title) : title, key, dir));
    }
    return Padding(
      key: key,
      padding: EdgeInsets.only(
        top: headingLevel != null ? _size * 0.5 : 0,
        bottom: bottom ?? (headingLevel != null ? _size * 0.4 : _paragraphGap),
      ),
      child: Text.rich(
        _buildSpan(runs, matches, first, breaks),
        textDirection: dir,
        textAlign: TextAlign.start,
      ),
    );
  }

  void _collect(List<md.Node> nodes, TextStyle style, List<_Run> out) {
    for (final n in nodes) {
      if (n is md.Text) {
        out.add(_Run(n.text.replaceAll('\n', ' '), style));
        continue;
      }
      if (n is! md.Element) {
        out.add(_Run(n.textContent, style));
        continue;
      }
      final kids = n.children ?? const <md.Node>[];
      final size = style.fontSize ?? _size;
      switch (n.tag) {
        case 'strong' || 'b':
          _collect(kids, style.copyWith(fontWeight: FontWeight.w700), out);
        case 'em' || 'i':
          _collect(kids, style.copyWith(fontStyle: FontStyle.italic), out);
        case 'del' || 's':
          _collect(
              kids, style.copyWith(decoration: TextDecoration.lineThrough), out);
        case 'code':
          out.add(_Run(
            n.textContent,
            _mono.copyWith(fontSize: size * 0.88, backgroundColor: palette.card),
            code: true,
          ));
        case 'a':
          _collect(
            kids,
            style.copyWith(
              color: palette.accent,
              decoration: TextDecoration.underline,
              decorationColor: palette.accent,
            ),
            out,
          );
        case 'br':
          out.add(_Run('\n', style));
        case 'img':
          out.add(_Run('', style,
              widget: _image(n.attributes['src'] ?? '', n.attributes['alt'] ?? '')));
        case 'input':
          final checked = n.attributes.containsKey('checked');
          out.add(_Run(checked ? '☑ ' : '☐ ', style.copyWith(color: palette.accent)));
        default:
          _collect(kids, style, out);
      }
    }
  }

  TextSpan _buildSpan(List<_Run> runs, List<MatchRange> matches, int first,
      [Set<int> breaks = const {}]) {
    final children = <InlineSpan>[];
    var offset = 0;
    var mi = 0;
    for (final run in runs) {
      if (run.widget != null) {
        children.add(WidgetSpan(
            child: run.widget!, alignment: PlaceholderAlignment.middle));
        continue;
      }
      final text = run.text;
      final runStart = offset;
      final runEnd = offset + text.length;
      // Text from [from] to [to] (block offsets), with the reading-order marks.
      String piece(int from, int to) {
        final raw = text.substring(from - runStart, to - runStart);
        if (breaks.isEmpty) return raw;
        final b = StringBuffer();
        for (var i = from; i < to; i++) {
          if (breaks.contains(i)) b.write(DirectionResolver.rlm);
          b.write(raw[i - from]);
        }
        return b.toString();
      }

      var pos = runStart;
      while (pos < runEnd) {
        while (mi < matches.length && matches[mi].end <= pos) {
          mi++;
        }
        if (mi < matches.length && matches[mi].start < runEnd) {
          final m = matches[mi];
          if (m.start > pos) {
            children.add(_span(piece(pos, m.start), run));
            pos = m.start;
          }
          final end = m.end < runEnd ? m.end : runEnd;
          final color = first + mi == currentMatch
              ? palette.currentHighlight
              : palette.highlight;
          children.add(_span(piece(pos, end), run, color));
          pos = end;
        } else {
          children.add(_span(piece(pos, runEnd), run));
          pos = runEnd;
        }
      }
      offset = runEnd;
    }
    return TextSpan(children: children);
  }

  TextSpan _span(String text, _Run run, [Color? highlight]) {
    var style = run.code ? run.style : applyFont(run.style);
    if (highlight != null) style = style.copyWith(backgroundColor: highlight);
    return TextSpan(text: text, style: style);
  }

  Widget _image(String src, String alt) {
    final fallback = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: palette.card, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.image_outlined, size: _size, color: palette.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(alt.isEmpty ? src : alt,
              style: TextStyle(color: palette.muted, fontSize: _size * 0.8)),
        ),
      ]),
    );
    if (!src.startsWith('http')) return fallback;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }

  Widget _codeBlock(md.Element e) {
    final text = e.textContent.replaceAll(RegExp(r'\n$'), '');
    final run = _Run(text, _mono, code: true);
    final key = _nextKey();
    final (matches, first) = _matchesFor(text, key);
    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: _paragraphGap),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: palette.card, borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text.rich(
              _buildSpan([run], matches, first),
              textDirection: TextDirection.ltr,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _quote(md.Element e) {
    final dir = resolver.resolve(e.textContent, fallback: documentDirection);
    final saved = _base;
    _base = _base.copyWith(color: palette.muted);
    final children = _blockList(e.children ?? const <md.Node>[]);
    _base = saved;
    return Padding(
      padding: EdgeInsets.only(bottom: _paragraphGap),
      child: Directionality(
        textDirection: dir,
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: 12),
          decoration: BoxDecoration(
            border: BorderDirectional(
                start: BorderSide(color: palette.accent, width: 3)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      ),
    );
  }

  Widget _list(md.Element e) {
    final ordered = e.tag == 'ol';
    var number = int.tryParse(e.attributes['start'] ?? '') ?? 1;
    final items = <Widget>[];
    _listDepth++;
    for (final li in (e.children ?? const <md.Node>[]).whereType<md.Element>()) {
      if (li.tag != 'li') continue;
      final dir = resolver.resolve(li.textContent, fallback: documentDirection);
      final isTask = (li.attributes['class'] ?? '').contains('task');
      final marker = isTask ? '' : (ordered ? '$number.' : '•');
      number++;
      items.add(Directionality(
        textDirection: dir,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (marker.isNotEmpty)
              SizedBox(
                width: _size * 1.6,
                child: Text(
                  marker,
                  textAlign: TextAlign.center,
                  style: applyFont(_base.copyWith(color: palette.accent)),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _blockList(li.children ?? const <md.Node>[]),
              ),
            ),
          ],
        ),
      ));
    }
    _listDepth--;
    return Padding(
      padding: EdgeInsets.only(bottom: _listDepth > 0 ? 0 : _size * 0.5),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }

  Widget _table(md.Element e) {
    final rows = <List<md.Element>>[];
    var headerRows = 0;
    for (final section in (e.children ?? const <md.Node>[]).whereType<md.Element>()) {
      final trs = section.tag == 'tr'
          ? [section]
          : (section.children ?? const <md.Node>[])
              .whereType<md.Element>()
              .where((r) => r.tag == 'tr');
      for (final tr in trs) {
        rows.add((tr.children ?? const <md.Node>[])
            .whereType<md.Element>()
            .where((c) => c.tag == 'th' || c.tag == 'td')
            .toList());
        if (section.tag == 'thead') headerRows++;
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final dir = resolver.resolve(e.textContent, fallback: documentDirection);
    return Padding(
      padding: EdgeInsets.only(bottom: _paragraphGap),
      child: Directionality(
        textDirection: dir,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: palette.line),
            children: [
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration:
                      i < headerRows ? BoxDecoration(color: palette.card) : null,
                  children: [
                    for (var c = 0; c < cols; c++)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: c < rows[i].length
                              ? _textBlock(
                                  rows[i][c].children ?? const <md.Node>[],
                                  i < headerRows
                                      ? _base.copyWith(fontWeight: FontWeight.w700)
                                      : _base,
                                  bottom: 0,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
