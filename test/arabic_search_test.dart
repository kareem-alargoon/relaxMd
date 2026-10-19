import 'package:flutter_test/flutter_test.dart';
import 'package:relaxmd/core/arabic_search.dart';

void main() {
  test('ignores tashkeel and keeps trailing marks in the match', () {
    const text = 'السَّلامُ عليكم';
    final m = ArabicSearch.find(text, 'السلام');
    expect(m, [const MatchRange(0, 9)]);
    expect(text.substring(m.first.start, m.first.end), 'السَّلامُ');
  });

  test('treats alef forms, taa marbuta and alef maqsura as equal', () {
    expect(ArabicSearch.find('قال أحمد', 'احمد'), hasLength(1));
    expect(ArabicSearch.find('إلى المدرسة', 'الي المدرسه'), hasLength(1));
    expect(ArabicSearch.find('آمن', 'امن'), hasLength(1));
  });

  test('ignores tatweel', () {
    expect(ArabicSearch.find('جمـــيل', 'جميل'), hasLength(1));
  });

  test('case sensitivity', () {
    expect(ArabicSearch.find('Hello hello', 'hello'), hasLength(2));
    expect(
        ArabicSearch.find(
            'Hello hello', 'hello', const SearchOptions(caseSensitive: true)),
        [const MatchRange(6, 11)]);
  });

  test('whole word', () {
    expect(
        ArabicSearch.find(
            'cat category', 'cat', const SearchOptions(wholeWord: true)),
        [const MatchRange(0, 3)]);
    expect(ArabicSearch.find('cat category', 'cat'), hasLength(2));
  });

  test('empty query finds nothing', () {
    expect(ArabicSearch.find('any text', '  '), isEmpty);
  });
}
