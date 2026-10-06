import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_metrics.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_bordered_surface.dart';

void main() {
  testWidgets('AppBorderedSurface width follows subpageScrollPadding inset (#410)',
      (tester) async {
    const viewportWidth = 400.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: viewportWidth,
              child: ListView(
                padding: AppMetrics.subpageScrollPadding,
                children: [
                  AppBorderedSurface(
                    key: const Key('bordered_surface'),
                    child: const SizedBox(height: 40, width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final box =
        tester.renderObject<RenderBox>(find.byKey(const Key('bordered_surface')));
    expect(
      box.size.width,
      closeTo(viewportWidth - 2 * AppMetrics.horizontalPadding, 0.5),
    );
  });
}
