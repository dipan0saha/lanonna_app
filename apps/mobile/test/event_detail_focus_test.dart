import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/domain/event_detail_focus.dart';

void main() {
  testWidgets('unfocusEventCommentComposer clears comment field focus',
      (tester) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            focusNode: focusNode,
            decoration: const InputDecoration(hintText: 'Comment'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    unfocusEventCommentComposer(focusNode);
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });
}
