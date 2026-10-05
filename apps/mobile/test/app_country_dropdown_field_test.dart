import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/data/iso_countries.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_country_dropdown_field.dart';

void main() {
  testWidgets('country dropdown hint uses regular weight not bodyLarge bold', (tester) async {
    const countries = [
      IsoCountry(code: 'US', name: 'United States'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppCountryDropdownField(
            countries: countries,
            value: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final hint = tester.widget<Text>(find.text('Select a country'));
    expect(hint.style?.fontWeight, FontWeight.w400);
  });
}
