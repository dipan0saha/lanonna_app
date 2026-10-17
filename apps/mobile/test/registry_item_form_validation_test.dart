import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/validation/form_validators.dart';
import 'package:lanonna/core/widgets/app_labeled_text_form_field.dart';

void main() {
  testWidgets('empty registry item name shows inline required error', (tester) async {
    final name = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var validateOnInteraction = false;

    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) {
            final autovalidate = validateOnInteraction
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled;
            return Scaffold(
              body: Form(
                key: formKey,
                autovalidateMode: autovalidate,
                child: Column(
                  children: [
                    AppLabeledTextFormField(
                      label: 'Item Name',
                      controller: name,
                      validator: (v) => validateRegistryItemName(AppLocalizations.of(context)!, v),
                      autovalidateMode: autovalidate,
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() => validateOnInteraction = true);
                        formKey.currentState?.validate();
                      },
                      child: const Text('Add Item'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Add Item'));
    await tester.pump();

    expect(find.text('Item name is required'), findsOneWidget);
  });
}
