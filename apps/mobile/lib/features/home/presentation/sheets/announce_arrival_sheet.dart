import 'package:flutter/material.dart';

import '../../../../core/time/app_date_time.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_modal_sheet.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../domain/announce_arrival_input.dart';
import '../../../onboarding/presentation/widgets/onboarding_buttons.dart';
import '../../../../l10n/app_localizations.dart';

typedef AnnounceArrivalCallback = Future<void> Function(DateTime birthDate);

Future<void> showAnnounceArrivalSheet(
  BuildContext context, {
  required AnnounceArrivalCallback onConfirm,
}) async {
  await showAppModalSheet<void>(
    context: context,
    title: AppLocalizations.of(context)!.actionAnnounceArrival2,
    subtitle:
        'Confirm the date of birth. Your home will update to celebrate your baby.',
    bodyBuilder: (ctx) {
      var selected = onboardingDateAtMidnight(DateTime.now());
      return StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selected,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selected = onboardingDateAtMidnight(picked));
                  }
                },
                child: Text(
                  formatApiCalendarDateFromParts(
                    selected,
                    localeNameForFormatting(context),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              OnboardingPrimaryButton(
                label: AppLocalizations.of(context)!.actionConfirm,
                onPressed: () async {
                  if (!birthDateValidForAnnounce(selected)) {
                    AppSnackBar.showAlert(
                      ctx,
                      'Date of birth cannot be in the future.',
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();
                  await onConfirm(selected);
                },
              ),
            ],
          );
        },
      );
    },
  );
}
