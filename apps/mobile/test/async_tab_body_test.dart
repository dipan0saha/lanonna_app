import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/widgets/async_tab_body.dart';

void main() {
  testWidgets('AsyncTabBody shows retry when error set', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncTabBody(
          loading: false,
          error: 'Network problem',
          onRetry: () => retried = true,
          child: const Text('content'),
        ),
      ),
    );

    expect(find.text('Network problem'), findsOneWidget);
    expect(find.text('content'), findsNothing);
    await tester.tap(find.byKey(const Key('async_tab_retry')));
    expect(retried, isTrue);
  });
}
