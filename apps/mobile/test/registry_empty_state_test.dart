import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/presentation/widgets/registry_empty_state.dart';

void main() {
  testWidgets('Registry empty state shows add for owner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistryEmptyState(isOwner: true, onAddItem: () {}),
        ),
      ),
    );
    expect(find.text('No registry items yet'), findsOneWidget);
    expect(find.text('+ Add Item'), findsOneWidget);
  });
}
