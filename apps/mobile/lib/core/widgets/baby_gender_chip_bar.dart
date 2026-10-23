import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../domain/baby_gender.dart';
import 'app_chip.dart';

/// App-wide chip accent for a baby gender: peach for Girl, sage otherwise.
extension BabyGenderChipAccent on BabyGender {
  AppChipAccent get chipAccent =>
      this == BabyGender.female ? AppChipAccent.peach : AppChipAccent.sage;
}

/// Boy / Girl picker for name suggestions (first moment, Fun > Names).
///
/// Exactly one of [BabyGender.male] or [BabyGender.female] is selected; Girl
/// uses the peach accent like the rest of the app.
class BabyGenderChipBar extends StatelessWidget {
  const BabyGenderChipBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  }) : assert(
         selected == BabyGender.male || selected == BabyGender.female,
         'Name suggestion gender is Boy or Girl only',
       );

  static const Key boyKey = Key('baby_gender_chip_boy');
  static const Key girlKey = Key('baby_gender_chip_girl');

  final BabyGender selected;
  final ValueChanged<BabyGender> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppToggleChipBar<BabyGender>(
      padding: padding,
      options: [
        for (final (gender, key) in const [
          (BabyGender.male, boyKey),
          (BabyGender.female, girlKey),
        ])
          AppToggleChipOption(
            gender,
            gender.label(l10n),
            chipKey: key,
            selectedAccent: gender.chipAccent,
          ),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}
