import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/validation/form_validators.dart';
import 'package:lanonna/core/widgets/app_country_dropdown_field.dart';
import 'package:lanonna/core/widgets/app_labeled_text_form_field.dart';
import 'package:lanonna/core/data/iso_countries.dart';

void main() {
  testWidgets('shipping form clears field errors after failed save when user fixes input',
      (tester) async {
    final line1 = TextEditingController();
    final city = TextEditingController();
    final postal = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var validateOnInteraction = false;
    String? countryCode;

    await tester.pumpWidget(
      MaterialApp(
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
                child: ListView(
                  children: [
                    AppLabeledTextFormField(
                      label: 'Street address',
                      controller: line1,
                      validator: validateRegistryShippingLine1,
                      autovalidateMode: autovalidate,
                    ),
                    AppLabeledTextFormField(
                      label: 'City',
                      controller: city,
                      validator: validateRegistryShippingCity,
                      autovalidateMode: autovalidate,
                    ),
                    AppLabeledTextFormField(
                      label: 'Zip / Postal code',
                      controller: postal,
                      validator: validateRegistryShippingPostalCode,
                      autovalidateMode: autovalidate,
                    ),
                    AppCountryDropdownField(
                      countries: const [
                        IsoCountry(code: 'US', name: 'United States'),
                      ],
                      value: countryCode,
                      validator: validateCountryCode,
                      autovalidateMode: autovalidate,
                      onChanged: (code) => setState(() => countryCode = code),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() => validateOnInteraction = true);
                        formKey.currentState?.validate();
                      },
                      child: const Text('Save address'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Save address'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Street address is required'), findsOneWidget);
    expect(find.text('Select a country'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'QA Test Address');
    await tester.enterText(find.byType(TextFormField).at(1), 'QA City');
    await tester.enterText(find.byType(TextFormField).at(2), '10001');
    await tester.pump();

    expect(find.text('Street address is required'), findsNothing);
    expect(find.text('City is required'), findsNothing);
    expect(find.text('Zip / Postal code is required'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('United States').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Select a country'), findsNothing);
    expect(find.text('United States'), findsWidgets);
  });
}
