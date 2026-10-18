import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The brand fonts, bundled with the app (PRD §5.1).
///
/// The theme styles text with `GoogleFonts.baloo2`, `GoogleFonts.inter` and
/// `GoogleFonts.dancingScript`; `google_fonts` finds each weight's file under
/// `assets/google_fonts/` (named `<Family>-<Weight>.ttf`) instead of
/// downloading it. The Inter and Baloo 2 files are the exact files
/// `google_fonts` would download (same SHA-256), so text renders the same.
abstract final class AppFonts {
  /// Every font variant the theme uses, and so every file that is bundled.
  /// A style in a weight that is not listed here would fail to load, which
  /// `test/app_fonts_test.dart` catches.
  static List<TextStyle> get bundledVariants => [
    GoogleFonts.baloo2(fontWeight: FontWeight.w700),
    GoogleFonts.baloo2(fontWeight: FontWeight.w800),
    GoogleFonts.inter(fontWeight: FontWeight.w400),
    GoogleFonts.inter(fontWeight: FontWeight.w500),
    GoogleFonts.inter(fontWeight: FontWeight.w600),
    GoogleFonts.inter(fontWeight: FontWeight.w700),
    GoogleFonts.dancingScript(fontWeight: FontWeight.w700),
  ];

  static const _licenses = {
    'Baloo 2': 'assets/google_fonts/Baloo2-OFL.txt',
    'Dancing Script': 'assets/google_fonts/DancingScript-OFL.txt',
    'Inter': 'assets/google_fonts/Inter-OFL.txt',
  };

  /// Fonts come only from the app bundle (never the network), and their OFL
  /// licenses show on the licenses page.
  static void configure() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LicenseRegistry.addLicense(() async* {
      for (final MapEntry(key: family, value: path) in _licenses.entries) {
        yield LicenseEntryWithLineBreaks([
          family,
        ], await rootBundle.loadString(path));
      }
    });
  }

  /// Loads every bundled variant, so the first frame is already drawn in the
  /// brand fonts instead of a fallback that swaps later. Start-up runs this
  /// alongside its other steps; it reads local assets only.
  static Future<void> preload() async {
    try {
      // Creating the styles starts loading their files.
      await GoogleFonts.pendingFonts(bundledVariants);
    } catch (e) {
      // Never block start-up: text falls back as it did before bundling.
      debugPrint('app_fonts_preload_failed: $e');
    }
  }
}
