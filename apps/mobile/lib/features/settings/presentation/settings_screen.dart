import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openHelp(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: const {'subject': 'La Nonna support'},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email to ${AppConfig.supportEmail}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
      title: l10n.settingsTitle,
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.settingsNotifications),
            subtitle: Text(l10n.settingsNotificationsSubtitle),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => context.push('/account/notification-preferences'),
          ),
          ListTile(
            title: Text(l10n.settingsEditProfile),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => context.push('/account/edit'),
          ),
          ListTile(
            title: Text(l10n.settingsHelpSupport),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => _openHelp(context),
          ),
        ],
      ),
    );
  }
}
