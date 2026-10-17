import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/l10n/placeholder_rich_text.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

String _plain(WidgetTester tester) =>
    tester.widget<RichText>(find.byType(RichText).first).text.toPlainText();

void main() {
  testWidgets('links are placed by placeholder, not by word search', (
    tester,
  ) async {
    // The link label "Terms" also appears literally earlier in the sentence,
    // and the placeholders come in the opposite order to the links.
    var privacy = 0;
    var terms = 0;
    await _pump(
      tester,
      PlaceholderRichText(
        message: (t) => 'Terms matter: read {${t[1]}} then {${t[0]}}.',
        placeholders: [
          MessagePlaceholder(label: 'Terms', onTap: () => terms++),
          MessagePlaceholder(label: 'Privacy', onTap: () => privacy++),
        ],
      ),
    );
    expect(_plain(tester), 'Terms matter: read {Privacy} then {Terms}.');
    final spans = <TextSpan>[];
    tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((
      s,
    ) {
      if (s is TextSpan && s.recognizer != null) spans.add(s);
      return true;
    });
    expect(spans.map((s) => s.text), ['Privacy', 'Terms']);
    (spans[0].recognizer! as dynamic).onTap();
    (spans[1].recognizer! as dynamic).onTap();
    expect((privacy, terms), (1, 1));
  });

  testWidgets('tapping a link and its semantics', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      PlaceholderRichText(
        message: (t) => 'Already have an account? ${t[0]}',
        placeholders: [MessagePlaceholder(label: 'Log in', onTap: () => taps++)],
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('Log in'));
    expect(taps, 1);
    expect(
      find.semantics.byPredicate(
        (n) =>
            n.label == 'Log in' &&
            n.hasFlag(SemanticsFlag.isLink) &&
            n.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('non-tappable spans are styled without a recognizer', (
    tester,
  ) async {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    await _pump(
      tester,
      PlaceholderRichText(
        message: (t) => '${t[0]} removed ${t[1]} from the family',
        placeholderStyle: bold,
        placeholders: const [
          MessagePlaceholder(label: 'Sarah'),
          MessagePlaceholder(label: 'Ann', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
    expect(_plain(tester), 'Sarah removed Ann from the family');
    final spans = <TextSpan>[];
    tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((
      s,
    ) {
      if (s is TextSpan && (s.text == 'Sarah' || s.text == 'Ann')) spans.add(s);
      return true;
    });
    expect(spans.map((s) => s.recognizer), [null, null]);
    expect(spans[0].style?.fontWeight, FontWeight.w700);
    expect(spans[1].style?.color, Colors.red);
    expect(
      PlaceholderRichText.plainText(
        (t) => '${t[0]} left',
        const [MessagePlaceholder(label: 'Sarah')],
      ),
      'Sarah left',
    );
  });
}
