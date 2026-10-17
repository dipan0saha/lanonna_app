import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/l10n/tappable_placeholder_rich_text.dart';

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
      TappablePlaceholderRichText(
        message: (t) => 'Terms matter: read {${t[1]}} then {${t[0]}}.',
        links: [
          PlaceholderLink(label: 'Terms', onTap: () => terms++),
          PlaceholderLink(label: 'Privacy', onTap: () => privacy++),
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
      TappablePlaceholderRichText(
        message: (t) => 'Already have an account? ${t[0]}',
        links: [PlaceholderLink(label: 'Log in', onTap: () => taps++)],
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
}
