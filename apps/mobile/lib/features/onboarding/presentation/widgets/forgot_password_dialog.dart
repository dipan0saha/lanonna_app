import 'package:flutter/material.dart';

import '../../../../core/validation/form_validators.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../l10n/app_localizations.dart';

/// Prompts for an email when the sign-in form does not already have a valid one.
Future<String?> showForgotPasswordEmailDialog(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _ForgotPasswordEmailDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordEmailDialog extends StatefulWidget {
  const _ForgotPasswordEmailDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordEmailDialog> createState() => _ForgotPasswordEmailDialogState();
}

class _ForgotPasswordEmailDialogState extends State<_ForgotPasswordEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.authPasswordResetDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.authPasswordResetDialogBody),
            const SizedBox(height: 16),
            AppTextFormField(
              key: const Key('forgot_password_email'),
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
              decoration: InputDecoration(
                labelText: l10n.authPasswordResetEmailLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.authPasswordResetCancel),
        ),
        FilledButton(
          key: const Key('forgot_password_send'),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: Text(l10n.authPasswordResetSend),
        ),
      ],
    );
  }
}
