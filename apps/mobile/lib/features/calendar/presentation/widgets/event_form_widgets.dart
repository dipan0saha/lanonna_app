import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/media/photo_selection.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/photo_selection_preview.dart';
import '../../../onboarding/presentation/widgets/onboarding_typography.dart';

/// Full-width cover slot from the calendar prototype (`cal-new` photo upload).
///
/// Previews the [selection] immediately (a picked file before it uploads) and
/// shows an upload spinner while [busy].
class PrototypeEventCoverUpload extends StatelessWidget {
  const PrototypeEventCoverUpload({
    super.key,
    required this.selection,
    required this.onTap,
    this.busy = false,
    this.onSignedUrlError,
  });

  final PhotoSelection selection;
  final VoidCallback? onTap;
  final bool busy;
  final VoidCallback? onSignedUrlError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = l10n.calendarPhotoOptional;
    final ref = selection.remoteRef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingFieldLabel(label),
        const SizedBox(height: AppMetrics.fieldLabelGap),
        AppSemantics.button(
          'calendar_event_cover',
          GestureDetector(
            onTap: busy ? null : onTap,
            child: PhotoSelectionPreview(
              selection: selection,
              width: double.infinity,
              height: AppMetrics.photoPickerCoverHeight,
              borderRadius: AppMetrics.photoPickerCoverRadius,
              busy: busy,
              cacheKey: ref == null ? null : 'event-cover-$ref',
              onSignedUrlError: onSignedUrlError,
            ),
          ),
          label: selection.hasPhoto
              ? l10n.photoChangeAction
              : l10n.photoAddAction,
        ),
        const SizedBox(height: AppMetrics.formFieldSpacing),
      ],
    );
  }
}
