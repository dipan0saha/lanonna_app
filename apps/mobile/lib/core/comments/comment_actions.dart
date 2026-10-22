import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/api_error_message.dart';
import '../input/app_text_input_kind.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';

/// Edit dialog. Returns normalized prose, or null when cancelled or blank.
Future<String?> showEditCommentDialog(
  BuildContext context,
  String initialText,
) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initialText);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.commentEditTitle),
      content: AppTextField(
        kind: AppTextInputKind.prose,
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(hintText: l10n.commentEditHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commentCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.commentSave),
        ),
      ],
    ),
  );
  if (saved != true) {
    controller.dispose();
    return null;
  }
  final text = AppTextInputPolicy.normalizeForSubmit(
    AppTextInputKind.prose,
    controller.text,
  );
  controller.dispose();
  if (text.isEmpty) return null;
  return text;
}

/// Delete confirmation. True only when the user confirms.
Future<bool> confirmDeleteComment(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return showConfirmDialog(
    context,
    title: l10n.commentDeleteTitle,
    confirmLabel: l10n.commentDeleteAction,
    cancelLabel: l10n.commentCancel,
  );
}

void showCommentError(BuildContext context, Object error) {
  AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, error));
}
