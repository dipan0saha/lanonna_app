import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_metrics.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_section_title.dart';

void main() {
  testWidgets('AppSectionTitle leaves sectionTitleGap before next child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionTitle(title: 'Preferences'),
              Container(
                key: const Key('content'),
                height: 40,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );

    final sectionBox = tester.renderObject<RenderBox>(find.byType(AppSectionTitle));
    final contentBox = tester.renderObject<RenderBox>(find.byKey(const Key('content')));
    final sectionBottom = sectionBox.localToGlobal(Offset(0, sectionBox.size.height)).dy;
    final contentTop = contentBox.localToGlobal(Offset.zero).dy;
    expect(contentTop - sectionBottom, closeTo(0, 0.5));

    final titleBox = tester.renderObject<RenderBox>(find.text('Preferences'));
    final titleBottom = titleBox.localToGlobal(Offset(0, titleBox.size.height)).dy;
    expect(sectionBottom - titleBottom, closeTo(AppMetrics.sectionTitleGap, 0.5));
  });
}
