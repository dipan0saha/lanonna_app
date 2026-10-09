import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/api/run_mutation.dart';
import 'package:lanonna/core/theme/app_theme.dart';

void main() {
  testWidgets('runMutation shows API message and returns false on failure',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final ok = await runMutation(
                    context,
                    () async {
                      throw ApiException(
                        'You already suggested a name for this gender.',
                        statusCode: 403,
                      );
                    },
                  );
                  expect(ok, isFalse);
                },
                child: const Text('Run'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Run'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final snack = find.byType(SnackBar);
    expect(snack, findsOneWidget);
    final snackBar = tester.widget<SnackBar>(snack);
    expect(
      (snackBar.content as Text).data,
      'You already suggested a name for this gender.',
    );
  });
}
