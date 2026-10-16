import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/registry_priority_chip.dart';

void main() {
  testWidgets('registry priority chip shows orange P label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: RegistryPriorityChip(priority: 5),
        ),
      ),
    );
    expect(find.text('P5'), findsOneWidget);
  });
}
