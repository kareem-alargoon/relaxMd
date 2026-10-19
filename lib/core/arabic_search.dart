/// A match in the original (not normalized) text, `start` inclusive and
/// `end` exclusive.
class MatchRange {
  const MatchRange(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is MatchRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MatchRange($start, $end)';
}

class SearchOptions {
  const SearchOptions({this.caseSensitive = false, this.wholeWord = false});

  final bool caseSensitive;
  final bool wholeWord;
}

class NormalizedText {
  const NormalizedText(this.text, this.map);

  final String text;

  /// `map[i]` is the index in the original text of normalized character `i`.
  final List<int> map;
}

/// Search that ignores tashkeel and tatweel and treats common Arabic letter
/// variants as equal (أ إ آ ٱ → ا, ة → ه, ى → ي).
class ArabicSearch {
  static final _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

  static bool isIgnorable(int c) =>
      (c >= 0x064B && c <= 0x065F) || c == 0x0670 || c == 0x0640;

  static int _fold(int c) {
    switch (c) {
      case 0x0623 || 0x0625 || 0x0622 || 0x0671:
        return 0x0627;
      case 0x0629:
        return 0x0647;
      case 0x0649:
        return 0x064A;
      default:
        return c;
    }
  }

  static NormalizedText normalize(String s, {bool caseSensitive = false}) {
    final buf = StringBuffer();
    final map = <int>[];
    for (var i = 0; i < s.length; i++) {
      final cu = s.codeUnitAt(i);
      if (isIgnorable(cu)) continue;
      var ch = String.fromCharCode(_fold(cu));
      if (!caseSensitive) ch = ch.toLowerCase();
      for (var k = 0; k < ch.length; k++) {
        buf.write(ch[k]);
        map.add(i);
      }
    }
    return NormalizedText(buf.toString(), map);
  }

  static List<MatchRange> find(String text, String query,
      [SearchOptions options = const SearchOptions()]) {
    final q = normalize(query, caseSensitive: options.caseSensitive).text;
    if (q.trim().isEmpty) return const [];
    final n = normalize(text, caseSensitive: options.caseSensitive);
    final out = <MatchRange>[];
    var from = 0;
    while (true) {
      final i = n.text.indexOf(q, from);
      if (i < 0) break;
      final endN = i + q.length;
      if (!options.wholeWord ||
          (_isBoundary(n.text, i - 1) && _isBoundary(n.text, endN))) {
        final start = n.map[i];
        var end = n.map[endN - 1] + 1;
        // Keep trailing diacritics with their letter so shaping isn't split.
        while (end < text.length && isIgnorable(text.codeUnitAt(end))) {
          end++;
        }
        out.add(MatchRange(start, end));
        from = endN;
      } else {
        from = i + 1;
      }
    }
    return out;
  }

  static bool _isBoundary(String s, int index) =>
      index < 0 || index >= s.length || !_wordChar.hasMatch(s[index]);
}
