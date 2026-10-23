import 'package:firebase_auth/firebase_auth.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/biometric_sign_in_service.dart';
import '../../../core/auth/auth_session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../data/account_repository.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  var _deleting = false;
  var _loadingPreview = true;
  DeleteAccountPreview? _preview;
  String? _previewError;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });
    try {
      final preview =
          await context.read<AccountRepository>().fetchDeleteAccountPreview();
      if (mounted) {
        setState(() {
          _preview = preview;
          _loadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewError = apiErrorMessage(AppLocalizations.of(context)!, e);
          _loadingPreview = false;
        });
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final babies = _preview?.soleOwnedBabies ?? const <SoleOwnedBaby>[];
    final body = babies.isEmpty
        ? l10n.deleteAccountConfirmBody
        : [
            l10n.deleteAccountConfirmBody,
            '',
            l10n.deleteAccountSoleOwnedHeading,
            for (final baby in babies)
              l10n.deleteAccountSoleOwnedBaby(babyNameLabel(l10n, baby.name)),
          ].join('\n');
    return showConfirmDialog(
      context,
      title: l10n.deleteAccountConfirmTitle,
      message: body,
      confirmLabel: l10n.deleteAccountConfirmAction,
      variant: ConfirmDialogVariant.destructive,
    );
  }

  Future<bool> _reauthenticateIfSupported() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthRepository>();
    if (auth.usesPasswordProvider) {
      final password = await _askPassword(l10n);
      if (password == null || !mounted) return false;
      try {
        await auth.reauthenticateWithPassword(password);
        return true;
      } on FirebaseAuthException {
        if (mounted) {
          AppSnackBar.showAlert(context, l10n.deleteAccountReauthFailed);
        }
        return false;
      }
    }
    if (auth.usesGoogleProvider) {
      try {
        await auth.reauthenticateWithGoogle();
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'cancelled' || !mounted) return false;
        AppSnackBar.showAlert(context, l10n.deleteAccountReauthFailed);
        return false;
      }
    }
    return true;
  }

  Future<String?> _askPassword(AppLocalizations l10n) {
    _passwordController.clear();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        var obscure = true;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(l10n.deleteAccountReauthPasswordTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.deleteAccountReauthPasswordBody),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.fieldPassword,
                    suffixIcon: AppIconButton(
                      semanticsId: 'delete_account_password_visibility',
                      label: obscure ? AppLocalizations.of(context)!.accountShowPassword : AppLocalizations.of(context)!.accountHidePassword,
                      onPressed: () => setLocal(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.authPasswordResetCancel),
              ),
              FilledButton(
                onPressed: () {
                  if (_passwordController.text.isEmpty) return;
                  Navigator.pop(ctx, _passwordController.text);
                },
                child: Text(l10n.deleteAccountReauthPasswordAction),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDelete();
    if (!confirmed || !mounted) return;
    final reauthed = await _reauthenticateIfSupported();
    if (!reauthed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await context.read<AccountRepository>().deleteAccount();
      if (!mounted) return;
      await context.read<BiometricSignInService>().clearLocalEnrollment();
      if (!mounted) return;
      await context.read<AuthSessionService>().signOut();
      if (mounted) context.go(OnboardingRoutes.ownerCarousel);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canDelete =
        _preview != null && !_loadingPreview && _previewError == null;

    return PrototypeSubpageScaffold(
      title: l10n.deleteAccountTitle,
      body: Padding(
        padding: AppMetrics.subpageScrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteAccountBody, style: context.textStyles.bodyMedium),
            if (_loadingPreview) ...[
              const SizedBox(height: 24),
              Text(
                l10n.deleteAccountChecking,
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
            if (_previewError != null) ...[
              const SizedBox(height: 16),
              Text(
                _previewError!,
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: (_deleting || !canDelete) ? null : _delete,
              child: Text(
                _deleting
                    ? l10n.deleteAccountDeleting
                    : l10n.deleteAccountButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
