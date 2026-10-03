import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_offline_wrapper.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('AppOfflineWrapper shows banner when offline', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectivityService>.value(
        value: ConnectivityService.forTesting(isOnline: false),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppOfflineWrapper(
            child: Center(child: Text('Body')),
          ),
        ),
      ),
    );

    expect(find.text("You're offline — showing saved content"), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('AppOfflineWrapper hides banner when online', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectivityService>.value(
        value: ConnectivityService.forTesting(isOnline: true),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppOfflineWrapper(
            child: Center(child: Text('Body')),
          ),
        ),
      ),
    );

    expect(find.text("You're offline — showing saved content"), findsNothing);
  });
}
