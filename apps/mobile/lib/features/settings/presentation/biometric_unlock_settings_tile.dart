import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/auth/biometric_sign_in_service.dart';
import '../../../core/auth/biometric_unlock_service.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../account/data/account_repository.dart';

/// One setting for biometric sign-in after Log out and the app lock
/// (`biometric_unlock_enabled`). Turning it on creates and registers this
/// install's device key (that prompt is the biometric check); turning it off
/// revokes every device key on the server and deletes this one.
class BiometricUnlockSettingsTile extends StatefulWidget {
  const BiometricUnlockSettingsTile({super.key, this.biometricService});

  final BiometricUnlockService? biometricService;

  @override
  State<BiometricUnlockSettingsTile> createState() =>
      _BiometricUnlockSettingsTileState();
}

class _BiometricUnlockSettingsTileState
    extends State<BiometricUnlockSettingsTile> {
  late final BiometricUnlockService _biometricService =
      widget.biometricService ?? BiometricUnlockService();
  var _loading = true;
  var _saving = false;
  var _deviceSupported = false;
  bool? _enabled;

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
    final signIn = context.read<BiometricSignInService>();
    setState(() {
      _deviceSupported = supported;
      _enabled = account != null
          ? signIn.isUnlockActiveForSignedInUser(
              serverBiometricUnlockEnabled: account.biometricUnlockEnabled,
            )
          : false;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    if (value && !_deviceSupported) {
      AppSnackBar.showAlert(context, l10n.settingsBiometricUnavailable);
      return;
    }
    final repo = context.read<AccountRepository>();
    final signIn = context.read<BiometricSignInService>();
    setState(() => _saving = true);
    final ok = await runMutation(context, () async {
      if (value) {
        await signIn.enroll(
          promptMessage: l10n.biometricUnlockReason,
          displayName: _firstName(repo.cachedAccount?.displayName),
        );
        try {
          await repo.setBiometricUnlockEnabled(true);
        } catch (_) {
          await signIn.clearLocalEnrollment();
          rethrow;
        }
      } else {
        // The server revokes every device key when the flag goes off.
        await repo.setBiometricUnlockEnabled(false);
        await signIn.clearLocalEnrollment();
      }
    });
    if (!mounted) return;
    setState(() {
      if (ok) _enabled = value;
      _saving = false;
    });
  }

  static String? _firstName(String? displayName) {
    final trimmed = displayName?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
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
    return AppSemantics.container(
      'settings_biometric_unlock',
      SwitchListTile(
        title: Text(l10n.settingsBiometricUnlock),
        subtitle: Text(l10n.settingsBiometricUnlockSubtitle),
        value: _enabled ?? false,
        onChanged: _saving ? null : _onChanged,
      ),
    );
  }
}
