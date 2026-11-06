import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaxmd/core/direction.dart';
import 'package:relaxmd/core/themes.dart';
import 'package:relaxmd/markdown/md_renderer.dart';

void main() {
  Future<RenderResult> pumpMarkdown(WidgetTester tester, String source,
      {String query = '', double threshold = 50}) async {
    late RenderResult result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          result = MdRenderer(
            palette: palettes['paper']!,
            bodyStyle: const TextStyle(fontSize: 16),
            resolver: DirectionResolver(
                mode: DirectionMode.auto, threshold: threshold),
            documentDirection: TextDirection.rtl,
            query: query,
          ).render(parseMarkdown(source));
          return ListView(children: result.blocks);
        }),
      ),
    ));
    return result;
  }

  TextDirection? directionOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).textDirection;

  testWidgets('each paragraph gets its own direction', (tester) async {
    await pumpMarkdown(tester, 'هذا نص عربي\n\nThis is English\n');
    expect(directionOf(tester, 'هذا نص عربي'), TextDirection.rtl);
    expect(directionOf(tester, 'This is English'), TextDirection.ltr);
  });

  testWidgets('sensitivity flips a mixed paragraph', (tester) async {
    const mixed = 'افتح ملف README.md من the main branch';
    await pumpMarkdown(tester, mixed);
    expect(directionOf(tester, mixed), TextDirection.ltr);
    await pumpMarkdown(tester, mixed, threshold: 20);
    expect(directionOf(tester, mixed), TextDirection.rtl);
  });

  testWidgets('code blocks stay LTR', (tester) async {
    await pumpMarkdown(tester, '```\nflutter build apk\n```\n');
    expect(directionOf(tester, 'flutter build apk'), TextDirection.ltr);
  });

  testWidgets('collects headings and search matches', (tester) async {
    final result = await pumpMarkdown(
        tester, '# مقدمة\n\nنص أول\n\n## Setup\n\nنص ثاني\n',
        query: 'نص');
    expect(result.headings.map((h) => h.text), ['مقدمة', 'Setup']);
    expect(result.headings.first.level, 1);
    expect(result.matchCount, 2);
  });

  testWidgets('renders lists and tables', (tester) async {
    await pumpMarkdown(
        tester, '- أول\n- ثاني\n\n| اسم | قيمة |\n|---|---|\n| أ | 1 |\n');
    expect(find.text('أول'), findsOneWidget);
    expect(find.text('ثاني'), findsOneWidget);
    expect(find.text('قيمة'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
  });

  testWidgets('English words keep reading order in an RTL paragraph',
      (tester) async {
    const line = 'لو المحادثة عدّت الـ num_ctx، Ollama بيشيل أقدم';
    final result = await pumpMarkdown(tester, line, query: 'Ollama');
    final shown = DirectionResolver.withLatinBreaks(line);
    expect(shown, isNot(line));
    expect(directionOf(tester, shown), TextDirection.rtl);
    // The invisible mark doesn't throw off search.
    expect(result.matchCount, 1);
  });
}
