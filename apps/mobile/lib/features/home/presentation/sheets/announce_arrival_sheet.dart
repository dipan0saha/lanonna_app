import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../domain/announce_arrival_input.dart';
import '../../../onboarding/presentation/widgets/onboarding_buttons.dart';

typedef AnnounceArrivalCallback = Future<void> Function(DateTime birthDate);

Future<void> showAnnounceArrivalSheet(
  BuildContext context, {
  required AnnounceArrivalCallback onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      var selected = onboardingDateAtMidnight(DateTime.now());
      return StatefulBuilder(
        builder: (context, setState) {
          final text = context.textStyles;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppMetrics.horizontalPadding,
              16,
              AppMetrics.horizontalPadding,
              20 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Announce arrival',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirm the date of birth. Your home will update to celebrate your baby.',
                  style: text.bodyMedium?.copyWith(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
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
                  child: Text(formatApiBirthDate(selected)),
                ),
                const SizedBox(height: 16),
                OnboardingPrimaryButton(
                  label: 'Confirm',
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
            ),
          );
        },
      );
    },
  );
}
