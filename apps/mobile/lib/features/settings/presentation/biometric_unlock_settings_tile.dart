import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/biometric_sign_in_service.dart';
import '../../../core/auth/biometric_unlock_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../account/data/account_repository.dart';

class BiometricUnlockSettingsTile extends StatefulWidget {
  const BiometricUnlockSettingsTile({
    super.key,
    this.biometricService,
    this.biometricSignInService,
  });

  final BiometricUnlockService? biometricService;
  final BiometricSignInService? biometricSignInService;

  @override
  State<BiometricUnlockSettingsTile> createState() =>
      _BiometricUnlockSettingsTileState();
}

class _BiometricUnlockSettingsTileState extends State<BiometricUnlockSettingsTile> {
  late final BiometricUnlockService _biometricService =
      widget.biometricService ?? BiometricUnlockService();
  var _loading = true;
  var _saving = false;
  var _deviceSupported = false;
  bool? _enabled;

  BiometricSignInService get _signInService =>
      widget.biometricSignInService ?? context.read<BiometricSignInService>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AccountRepository>();
    final supported = await _biometricService.canCheckBiometrics();
    if (!mounted) return;
    AccountPayload? account = repo.cachedAccount;
    if (account == null) {
      try {
        account = await repo.fetchAccount();
      } catch (_) {
        account = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _deviceSupported = supported;
      _enabled = account?.biometricUnlockEnabled ?? false;
      _loading = false;
    });
  }

  String _accountHint(AccountPayload? account) {
    final email = account?.email ?? context.read<AuthRepository>().currentUser?.email;
    if (email == null || email.isEmpty) {
      return account?.displayName ?? 'your account';
    }
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}***${email.substring(at)}';
  }

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final repo = context.read<AccountRepository>();
    final auth = context.read<AuthRepository>();
    if (value) {
      if (!_deviceSupported) {
        AppSnackBar.showAlert(context, l10n.settingsBiometricUnavailable);
        return;
      }
      final ok = await _biometricService.authenticate(
        reason: l10n.biometricUnlockReason,
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      if (value) {
        final user = auth.currentUser ?? FirebaseAuth.instance.currentUser;
        if (user == null) {
          AppSnackBar.showAlert(context, l10n.errorGeneric);
          return;
        }
        final account = repo.cachedAccount;
        await _signInService.enrollAfterBiometricUnlockEnabled(
          firebaseUid: user.uid,
          accountHint: _accountHint(account),
          promptMessage: l10n.biometricUnlockReason,
        );
        await repo.setBiometricUnlockEnabled(true);
      } else {
        await _signInService.revokeEnrollment(deleteKeys: true);
        await repo.setBiometricUnlockEnabled(false);
      }
      if (mounted) {
        setState(() => _enabled = value);
      }
    } catch (_) {
      if (value) {
        await _signInService.revokeEnrollment(deleteKeys: true);
      }
      if (mounted) {
        AppSnackBar.showAlert(context, l10n.biometricSignInFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const ListTile(
        title: Text('…'),
        trailing: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SwitchListTile(
      title: Text(l10n.settingsBiometricUnlock),
      subtitle: Text(l10n.settingsBiometricUnlockSubtitle),
      value: _enabled ?? false,
      onChanged: _saving ? null : _onChanged,
    );
  }
}
