import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_text_field.dart';
import 'package:lanonna/core/widgets/app_text_form_field.dart';

void main() {
  Future<FontWeight?> editableWeight(WidgetTester tester, Widget child) async {
    late FontWeight? weight;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    weight = editable.style.fontWeight;
    return weight;
  }

  testWidgets('AppTextField uses regular input weight', (tester) async {
    final weight = await editableWeight(
      tester,
      const AppTextField(decoration: InputDecoration(hintText: 'hint')),
    );
    expect(weight, FontWeight.w400);
  });

  testWidgets('AppTextFormField uses regular input weight', (tester) async {
    final weight = await editableWeight(
      tester,
      const AppTextFormField(decoration: InputDecoration(hintText: 'hint')),
    );
    expect(weight, FontWeight.w400);
  });
}
