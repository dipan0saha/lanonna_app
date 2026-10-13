import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/biometric_unlock_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../account/data/account_repository.dart';

class BiometricUnlockSettingsTile extends StatefulWidget {
  const BiometricUnlockSettingsTile({
    super.key,
    this.biometricService,
  });

  final BiometricUnlockService? biometricService;

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

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
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
    final repo = context.read<AccountRepository>();
    setState(() => _saving = true);
    try {
      await repo.setBiometricUnlockEnabled(value);
      if (mounted) {
        setState(() => _enabled = value);
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
