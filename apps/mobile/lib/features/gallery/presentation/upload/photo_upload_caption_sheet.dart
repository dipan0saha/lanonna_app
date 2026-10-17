import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_modal_sheet.dart';
import '../../../../core/widgets/app_responsive_button_pair.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';

/// Optional caption before uploading a gallery photo. Returns trimmed caption or `null` if skipped.
Future<String?> showPhotoUploadCaptionSheet(
  BuildContext context, {
  required File imageFile,
}) {
  return showAppModalSheet<String?>(
    context: context,
    title: AppLocalizations.of(context)!.actionAddGallery,
    showClose: false,
    bodyBuilder: (context) => _PhotoUploadCaptionSheet(imageFile: imageFile),
  );
}

class _PhotoUploadCaptionSheet extends StatefulWidget {
  const _PhotoUploadCaptionSheet({required this.imageFile});

  final File imageFile;

  @override
  State<_PhotoUploadCaptionSheet> createState() =>
      _PhotoUploadCaptionSheetState();
}

class _PhotoUploadCaptionSheetState extends State<_PhotoUploadCaptionSheet> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _post() {
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _controller.text,
    );
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  void _skip() => Navigator.pop(context, null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppMetrics.fieldRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: AppMetrics.sheetImagePreviewMaxHeight,
              ),
              child: Image.file(widget.imageFile, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppSemantics.textField(
            'gallery_upload_caption',
            AppTextField(
              kind: AppTextInputKind.prose,
              controller: _controller,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.actionAddCaption,
                counterText: '',
              ),
              onSubmitted: (_) => _post(),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppResponsiveButtonPair(
            start: AppSemantics.button(
              'gallery_upload_skip',
              OutlinedButton(onPressed: _skip, child: Text(AppLocalizations.of(context)!.actionSkip)),
            ),
            end: AppSemantics.button(
              'gallery_upload_post',
              FilledButton(onPressed: _post, child: Text(AppLocalizations.of(context)!.actionPost)),
            ),
          ),
        ],
      ),
    );
  }
}
