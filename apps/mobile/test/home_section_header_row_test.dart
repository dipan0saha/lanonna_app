import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_metrics.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/presentation/widgets/home_section_header.dart';
import 'package:lanonna/features/home/presentation/widgets/home_section_trailing.dart';

void main() {
  testWidgets('link and meta trailings share title-to-body distance', (tester) async {
    Future<void> pumpHeader(HomeSectionTrailing? trailing) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeSectionHeader(title: 'Family Insight', trailing: trailing),
                Container(
                  key: const Key('body'),
                  height: 40,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );
    }

    double titleToBodyGap() {
      final titleBox = tester.renderObject<RenderBox>(find.text('FAMILY INSIGHT'));
      final bodyBox = tester.renderObject<RenderBox>(find.byKey(const Key('body')));
      final titleBottom = titleBox.localToGlobal(Offset(0, titleBox.size.height)).dy;
      final bodyTop = bodyBox.localToGlobal(Offset.zero).dy;
      return bodyTop - titleBottom;
    }

    await pumpHeader(HomeSectionLink(label: 'View all', onPressed: () {}));
    final linkGap = titleToBodyGap();

    await pumpHeader(const HomeSectionMeta(text: '2 / 5'));
    final metaGap = titleToBodyGap();

    expect(linkGap, closeTo(metaGap, 1));
    expect(linkGap, greaterThanOrEqualTo(AppMetrics.sectionTitleGap - 1));
  });
}
