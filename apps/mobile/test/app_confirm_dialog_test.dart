import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_colors.dart';
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
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('renders as a bottom sheet with title and message', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      onOpen: (context) async {
        await showConfirmDialog(
          context,
          title: 'Delete item?',
          message: 'Cannot undo.',
          confirmLabel: 'Delete',
        );
      },
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Delete item?'), findsOneWidget);
    expect(find.text('Cannot undo.'), findsOneWidget);
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

  testWidgets('destructive confirm uses the shared error button style', (
    tester,
  ) async {
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

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete'),
    );
    final style = button.style!;
    expect(style.backgroundColor?.resolve({}), AppColors.error);
    expect(style.foregroundColor?.resolve({}), AppColors.surface);
  });

  testWidgets('sequence stops on first cancel', (tester) async {
    var step = 0;
    bool? result;
    await _pumpHost(
      tester,
      onOpen: (context) async {
        result = await showConfirmDialogSequence(context, [
          ConfirmDialogStep(title: 'Step one', confirmLabel: 'Next'),
          ConfirmDialogStep(title: 'Step two', confirmLabel: 'Done'),
        ]);
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
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step two'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
