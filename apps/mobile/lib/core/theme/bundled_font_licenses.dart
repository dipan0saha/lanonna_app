import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers OFL licenses for fonts bundled under `assets/google_fonts/`
/// so they appear on the Flutter licenses page.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString(
      'assets/google_fonts/DancingScript-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Dancing Script'], ofl);
  });
}
