import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/presentation/widgets/home_teasers_section.dart';
import 'package:lanonna/l10n/app_localizations.dart';

/// Icon-only controls must carry a label. [AppIconButton] requires one, so a
/// raw [IconButton] anywhere else in `lib/` fails this test.
void main() {
  test('lib has no IconButton outside AppIconButton', () {
    final lib = Directory('lib');
    final iconButton = RegExp(r'(?<![A-Za-z0-9_])IconButton(?:\.\w+)?\s*\(');
    final violations = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_icon_button.dart')) continue;
      final source = _stripComments(entity.readAsStringSync());
      if (iconButton.hasMatch(source)) {
        violations.add(entity.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Use AppIconButton (label + semantics id) instead of IconButton: '
          '${violations.join(', ')}',
    );
  });

  testWidgets('home recent photo thumbnails are labeled Open photo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: HomeTeasersSection(
            teasers: HomeTeasers(
              recentPhotos: [HomeTeaserPhoto(id: 'photo-1')],
              upcomingEvents: [],
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Open photo'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('home_recent_photo_photo-1'),
      findsOneWidget,
    );
  });
}

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks
      .split('\n')
      .map((line) {
        final slash = line.indexOf('//');
        return slash < 0 ? line : line.substring(0, slash);
      })
      .join('\n');
}
