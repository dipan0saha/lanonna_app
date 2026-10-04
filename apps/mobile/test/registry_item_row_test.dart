import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/presentation/widgets/registry_item_row.dart';

RegistryItem _sampleItem() => RegistryItem(
      id: '1',
      name: 'Car seat',
      priority: 3,
      isPurchased: false,
    );

void main() {
  testWidgets('owner needed row shows Mark as purchased', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistryNeededRow(
            item: _sampleItem(),
            isOwner: true,
            currentUid: 'uid',
            onClaim: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
    expect(find.text('Mark as purchased'), findsOneWidget);
    expect(find.text("I'll buy this"), findsNothing);
  });

  testWidgets('follower needed row shows I will buy this', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistryNeededRow(
            item: _sampleItem(),
            isOwner: false,
            currentUid: 'uid',
            onClaim: () {},
          ),
        ),
      ),
    );
    expect(find.text("I'll buy this"), findsOneWidget);
    expect(find.text('Mark as purchased'), findsNothing);
  });
}
