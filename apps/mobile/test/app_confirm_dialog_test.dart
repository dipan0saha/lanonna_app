import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_confirm_dialog.dart';
import 'package:lanonna/l10n/app_localizations.dart';

Future<void> _pumpHost(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirm returns true and cancel returns false', (tester) async {
    bool? result;
    await _pumpHost(
      tester,
      onOpen: (context) async {
        result = await showConfirmDialog(
          context,
          title: 'Delete item?',
          message: 'Cannot undo.',
          confirmLabel: 'Delete',
        );
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('barrier dismiss returns false', (tester) async {
    bool? result;
    await _pumpHost(
      tester,
      onOpen: (context) async {
        result = await showConfirmDialog(
          context,
          title: 'Sure?',
          confirmLabel: 'OK',
        );
      },
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('destructive confirm uses error color from theme', (tester) async {
    await _pumpHost(
      tester,
      onOpen: (context) async {
        await showConfirmDialog(
          context,
          title: 'Delete?',
          confirmLabel: 'Delete',
          variant: ConfirmDialogVariant.destructive,
        );
      },
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    final scheme = AppTheme.light.colorScheme;
    final style = button.style!.resolve({});
    expect(style?.backgroundColor, scheme.error);
    expect(style?.foregroundColor, scheme.onError);
  });

  testWidgets('typed confirmation enables confirm only when phrase matches', (
    tester,
  ) async {
    bool? result;
    await _pumpHost(
      tester,
      onOpen: (context) async {
        result = await showConfirmDialog(
          context,
          title: 'Type to confirm',
          confirmLabel: 'Proceed',
          typedConfirmationPhrase: 'DELETE',
        );
      },
    );

    final proceed = find.widgetWithText(FilledButton, 'Proceed');
    FilledButton filled = tester.widget(proceed);
    expect(filled.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    filled = tester.widget(proceed);
    expect(filled.onPressed, isNotNull);

    await tester.tap(proceed);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('sequence stops on first cancel', (tester) async {
    var step = 0;
    bool? result;
    await _pumpHost(
      tester,
      onOpen: (context) async {
        result = await showConfirmDialogSequence(
          context,
          [
            ConfirmDialogStep(
              title: 'Step one',
              confirmLabel: 'Next',
            ),
            ConfirmDialogStep(
              title: 'Step two',
              confirmLabel: 'Done',
            ),
          ],
        );
      },
    );

    expect(find.text('Step one'), findsOneWidget);
    step++;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(step, 1);
    expect(find.text('Step two'), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step two'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
