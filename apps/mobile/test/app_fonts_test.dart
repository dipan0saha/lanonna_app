import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lanonna/core/theme/app_fonts.dart';
import 'package:lanonna/core/theme/app_text_theme.dart';
import 'package:lanonna/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Set<String> bundledFamilies() => {
    for (final s in AppFonts.bundledVariants) s.fontFamily!,
  };

  // The slots AppTextTheme defines (displayMedium is not used, so Material's
  // default stays there).
  test('every font the theme uses is a bundled variant', () {
    final theme = AppTheme.light;
    final t = theme.textTheme;
    final styles = <TextStyle?>[
      t.displayLarge,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
      AppTextTheme.fieldInput(t),
      AppTextTheme.keepsakeScriptName(t),
      for (final states in [
        <WidgetState>{},
        {WidgetState.selected},
      ])
        theme.navigationBarTheme.labelTextStyle?.resolve(states),
    ];
    final families = {
      for (final s in styles)
        if (s?.fontFamily != null) s!.fontFamily!,
    };
    expect(families, isNotEmpty);
    expect(
      bundledFamilies().containsAll(families),
      isTrue,
      reason: 'not bundled: ${families.difference(bundledFamilies())}',
    );
  });

  test(
    'every bundled variant loads from assets with runtime fetching off',
    () async {
      GoogleFonts.config.allowRuntimeFetching = false;
      addTearDown(() => GoogleFonts.config.allowRuntimeFetching = true);
      // Throws if any variant's file is missing from assets/google_fonts/.
      await GoogleFonts.pendingFonts(AppFonts.bundledVariants);
    },
  );

  test(
    'configure turns runtime fetching off and registers the licenses',
    () async {
      addTearDown(() => GoogleFonts.config.allowRuntimeFetching = true);
      AppFonts.configure();
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
      final packages = <String>{};
      await for (final entry in LicenseRegistry.licenses) {
        packages.addAll(entry.packages);
      }
      expect(packages, containsAll(['Baloo 2', 'Dancing Script', 'Inter']));
    },
  );

  test(
    'the Inter and Baloo 2 files are the ones google_fonts downloads',
    () async {
      // Byte lengths from google_fonts 6.3.3's manifest (its SHA-256s were
      // checked when the files were added).
      const lengths = {
        'Baloo2-Bold.ttf': 417936,
        'Baloo2-ExtraBold.ttf': 417540,
        'Inter-Regular.ttf': 303384,
        'Inter-Medium.ttf': 308288,
        'Inter-SemiBold.ttf': 309376,
        'Inter-Bold.ttf': 309732,
      };
      for (final MapEntry(key: file, value: length) in lengths.entries) {
        final data = await rootBundle.load('assets/google_fonts/$file');
        expect(data.lengthInBytes, length, reason: file);
      }
    },
  );
}
