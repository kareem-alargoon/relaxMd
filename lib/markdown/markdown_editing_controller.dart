import 'package:flutter/material.dart';

import '../core/arabic_search.dart';

class StyledRange {
  const StyledRange(this.start, this.end, this.style);

  final int start;
  final int end;
  final TextStyle style;
}

/// Splits [text] into spans so each part gets the merged style of every
/// range covering it. Ranges may overlap.
TextSpan styleRanges(String text, TextStyle? base, List<StyledRange> ranges) {
  if (ranges.isEmpty) return TextSpan(text: text, style: base);
  int clampIndex(int v) => v < 0 ? 0 : (v > text.length ? text.length : v);
  final points = <int>{0, text.length};
  for (final r in ranges) {
    points
      ..add(clampIndex(r.start))
      ..add(clampIndex(r.end));
  }
  final sorted = points.toList()..sort();
  final ordered = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final active = <StyledRange>[];
  final children = <TextSpan>[];
  var next = 0;
  for (var i = 0; i < sorted.length - 1; i++) {
    final a = sorted[i];
    final b = sorted[i + 1];
    if (a == b) continue;
    active.removeWhere((r) => r.end <= a);
    while (next < ordered.length && ordered[next].start <= a) {
      if (ordered[next].end > a) active.add(ordered[next]);
      next++;
    }
    TextStyle? style;
    for (final r in active) {
      style = style == null ? r.style : style.merge(r.style);
    }
    children.add(TextSpan(text: text.substring(a, b), style: style));
  }
  return TextSpan(style: base, children: children);
}

/// Text controller that tints Markdown markers and highlights search matches
/// in the raw editor.
class MarkdownEditingController extends TextEditingController {
  Color accent = const Color(0xFF2F6F62);
  Color muted = const Color(0xFF8C8577);
  Color highlight = const Color(0xFFF2D98B);
  Color currentHighlight = const Color(0xFFF0A830);
  List<MatchRange> matches = const [];
  int currentMatch = -1;

  static final _marker = RegExp(
    r'^ {0,3}#{1,6}(?=[ \t]|$)'
    r'|^[ \t]*(?:[-*+]|\d+[.)])(?:[ \t]+\[[ xX]\])?(?=[ \t])'
    r'|^[ \t]*>+'
    r'|\*\*|__|~~|`+',
    multiLine: true,
  );
  static final _fence = RegExp(r'^[ \t]*```.*$', multiLine: true);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    final ranges = <StyledRange>[
      for (final m in _marker.allMatches(t))
        StyledRange(m.start, m.end, TextStyle(color: accent)),
      for (final m in _fence.allMatches(t))
        StyledRange(m.start, m.end, TextStyle(color: muted)),
    ];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      if (m.end > t.length) continue;
      ranges.add(StyledRange(m.start, m.end,
          TextStyle(backgroundColor: i == currentMatch ? currentHighlight : highlight)));
    }
    final composing = value.composing;
    if (withComposing && value.isComposingRangeValid && !composing.isCollapsed) {
      ranges.add(StyledRange(composing.start, composing.end,
          const TextStyle(decoration: TextDecoration.underline)));
    }
    return styleRanges(t, style, ranges);
  }
}
