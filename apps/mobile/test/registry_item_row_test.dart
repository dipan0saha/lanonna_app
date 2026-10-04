import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/presentation/widgets/registry_item_row.dart';

RegistryItem _sampleItem({
  String name = 'Car seat',
  String? description,
}) =>
    RegistryItem(
      id: '1',
      name: name,
      description: description,
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

  testWidgets('owner needed row uses full width for long copy at phone width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: RegistryNeededRow(
                item: _sampleItem(
                  name: 'Crib & Mattress',
                  description: 'Safe sleep setup before baby arrives',
                ),
                isOwner: true,
                currentUid: 'uid',
                onClaim: () {},
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Crib & Mattress'), findsOneWidget);
    expect(find.text('Safe sleep setup before baby arrives'), findsOneWidget);
    expect(find.text('Mark as purchased'), findsOneWidget);
  });
}
