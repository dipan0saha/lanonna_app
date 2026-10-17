import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../l10n/app_localizations.dart';

/// Multicolor Google "G" for sign-in buttons (see assets/branding/google_sign_in_g.svg).
class GoogleLogoMark extends StatelessWidget {
  const GoogleLogoMark({super.key, this.size = 20});

  final double size;

  static const assetPath = 'assets/branding/google_sign_in_g.svg';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      semanticsLabel: l10n.brandGoogle,
    );
  }
}
