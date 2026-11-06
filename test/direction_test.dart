import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaxmd/core/direction.dart';

void main() {
  DirectionResolver auto(double threshold) =>
      DirectionResolver(mode: DirectionMode.auto, threshold: threshold);

  // 3 Arabic words, 4 English words: 43% Arabic.
  const mixed = 'افتح ملف README.md من the main branch';

  test('counts Arabic and Latin words, ignoring URLs and inline code', () {
    final c = DirectionResolver.count('زر https://example.com/a `some code` ok');
    expect(c.arabic, 1);
    expect(c.latin, 1);
  });

  test('pure Arabic is RTL and pure English is LTR', () {
    expect(auto(50).resolve('هذا نص عربي'), TextDirection.rtl);
    expect(auto(50).resolve('Plain English text'), TextDirection.ltr);
  });

  test('sensitivity threshold decides mixed lines', () {
    expect(auto(50).resolve(mixed), TextDirection.ltr);
    expect(auto(43).resolve(mixed), TextDirection.ltr);
    expect(auto(42).resolve(mixed), TextDirection.rtl);
    expect(auto(0).resolve(mixed), TextDirection.rtl);
  });

  test('a single Arabic word is enough at zero', () {
    expect(auto(0).resolve('Read the docs at home اليوم'), TextDirection.rtl);
  });

  test('lines without Arabic stay LTR even at zero', () {
    expect(auto(0).resolve('Only English here'), TextDirection.ltr);
  });

  test('lines without words use the fallback', () {
    expect(auto(50).resolve('123 - 456', fallback: TextDirection.ltr),
        TextDirection.ltr);
    expect(auto(50).resolve('', fallback: TextDirection.rtl), TextDirection.rtl);
  });

  test('forced modes ignore the text', () {
    const rtl = DirectionResolver(mode: DirectionMode.rtl, threshold: 50);
    const ltr = DirectionResolver(mode: DirectionMode.ltr, threshold: 50);
    expect(rtl.resolve('English only'), TextDirection.rtl);
    expect(ltr.resolve('عربي فقط'), TextDirection.ltr);
  });

  group('latinBreaks keeps English words in reading order', () {
    const rlm = DirectionResolver.rlm;

    test('splits English words around an Arabic comma', () {
      const text = 'لو المحادثة عدّت الـ num_ctx، Ollama بيشيل';
      expect(DirectionResolver.withLatinBreaks(text),
          'لو المحادثة عدّت الـ num_ctx،$rlm Ollama بيشيل');
    });

    test('splits at a comma, colon or spaced dash', () {
      expect(DirectionResolver.withLatinBreaks('نستخدم Python, Java هنا'),
          'نستخدم Python,$rlm Java هنا');
      expect(DirectionResolver.withLatinBreaks('خلي Note: ctx كده'),
          'خلي Note:$rlm ctx كده');
      expect(DirectionResolver.withLatinBreaks('بين GPU - CPU فرق'),
          'بين GPU -$rlm CPU فرق');
    });

    test('leaves file names, URLs and plain spaces alone', () {
      for (final text in [
        'افتح ملف README.md من the main branch',
        'زر https://example.com/a ok',
        'الساعة 10:30 تمام',
      ]) {
        expect(DirectionResolver.latinBreaks(text), isEmpty, reason: text);
      }
    });

    test('needs English on both sides', () {
      expect(DirectionResolver.latinBreaks('شغل Ollama، وبعدين'), isEmpty);
      expect(DirectionResolver.latinBreaks('خلاص، Ollama شغال'), isEmpty);
    });
  });
}
