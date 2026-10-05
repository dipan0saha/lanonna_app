import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../data/notifications_repository.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  NotificationPreferences? _prefs;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await context.read<NotificationsRepository>().fetchPreferences();
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() => _saving = true);
    try {
      final updated = await context.read<NotificationsRepository>().updatePreferences(
        digest: prefs.digest,
        pushEnabled: prefs.pushEnabled,
        emailDigestEnabled: prefs.emailDigestEnabled,
        notifyGalleryEnabled: prefs.notifyGalleryEnabled,
        notifyCalendarEnabled: prefs.notifyCalendarEnabled,
        notifyRegistryEnabled: prefs.notifyRegistryEnabled,
        notifyCommentsEnabled: prefs.notifyCommentsEnabled,
      );
      setState(() => _prefs = updated);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = _prefs;
    return PrototypeSubpageScaffold(
      title: l10n.settingsNotifications,
      body: _loading || prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'How often would you like updates?',
                  style: context.textStyles.titleSmall,
                ),
                const SizedBox(height: 12),
                _digestTile('realtime', 'Real-time', prefs),
                _digestTile('daily', 'Daily digest', prefs),
                _digestTile('weekly', 'Weekly digest', prefs),
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text('Get alerts on your phone'),
                  value: prefs.pushEnabled,
                  onChanged: (v) => setState(() => _prefs = prefs.copyWith(pushEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text('Weekly email digest'),
                  subtitle: const Text('Photos, events and registry updates'),
                  value: prefs.emailDigestEnabled,
                  onChanged: (v) =>
                      setState(() => _prefs = prefs.copyWith(emailDigestEnabled: v)),
                ),
                const SizedBox(height: 16),
                Text('Notification channels', style: context.textStyles.titleSmall),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(l10n.notificationChannelGallery),
                  subtitle: Text(l10n.notificationChannelGallerySubtitle),
                  value: prefs.notifyGalleryEnabled,
                  onChanged: (v) =>
                      setState(() => _prefs = prefs.copyWith(notifyGalleryEnabled: v)),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelCalendar),
                  subtitle: Text(l10n.notificationChannelCalendarSubtitle),
                  value: prefs.notifyCalendarEnabled,
                  onChanged: (v) =>
                      setState(() => _prefs = prefs.copyWith(notifyCalendarEnabled: v)),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelRegistry),
                  subtitle: Text(l10n.notificationChannelRegistrySubtitle),
                  value: prefs.notifyRegistryEnabled,
                  onChanged: (v) =>
                      setState(() => _prefs = prefs.copyWith(notifyRegistryEnabled: v)),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationChannelComments),
                  subtitle: Text(l10n.notificationChannelCommentsSubtitle),
                  value: prefs.notifyCommentsEnabled,
                  onChanged: (v) =>
                      setState(() => _prefs = prefs.copyWith(notifyCommentsEnabled: v)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? l10n.notificationPrefsSaving : l10n.notificationPrefsSave,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _digestTile(String value, String label, NotificationPreferences prefs) {
    final selected = prefs.digest == value;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.primaryDark : AppColors.muted,
      ),
      title: Text(label),
      onTap: () => setState(() => _prefs = prefs.copyWith(digest: value)),
    );
  }
}
