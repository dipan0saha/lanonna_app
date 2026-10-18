import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/baby_display_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/account_repository.dart';
import '../../account/data/notifications_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/domain/app_routes.dart';
import '../../home/presentation/widgets/home_top_bar.dart';
import 'baby_switcher_sheet.dart';

Widget shellHomeTopBar(BuildContext context) {
  return const _ShellTopBar();
}

/// Shell invite action: owner baby required before batch invite.
Future<void> onShellInviteFamilyTap(BuildContext context) async {
  final store = context.read<SelectedBabyStore>();
  final baby = await context.read<HomeRepository>().resolveOwnerBaby(store);
  if (!context.mounted) return;
  if (baby == null) {
    await showShellInviteRequiresOwnerBabyDialog(context);
    return;
  }
  await context.push(AppRoutes.inviteFamily);
}

Future<void> showShellInviteRequiresOwnerBabyDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.shellInviteRequiresOwnerBabyTitle),
      content: Text(l10n.shellInviteRequiresOwnerBabyMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.authPasswordResetCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ctx.push('/baby/create');
          },
          child: Text(l10n.actionAddBaby),
        ),
      ],
    ),
  );
}

/// The shell top bar: a view over shared state, so the five tab copies cost
/// no requests. Title from [SelectedBabyStore], bell dot from
/// [NotificationsRepository.unread], avatar from [AccountRepository]; all are
/// kept current once for the whole shell by `ShellChromeSync`.
class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SelectedBabyStore>();
    final notificationsRepo = context.read<NotificationsRepository>();
    final accountRepo = context.read<AccountRepository>();
    final l10n = AppLocalizations.of(context)!;
    // The selected baby's name as last resolved from the server (kept by
    // SelectedBabyStore so it survives an offline cold start).
    final title = store.hasResolvedSelectedBaby
        ? babyNameLabel(l10n, store.selectedBabyName)
        : null;
    return ListenableBuilder(
      listenable: Listenable.merge([
        notificationsRepo.unread,
        accountRepo.profileUpdates,
      ]),
      builder: (context, _) {
        final account = accountRepo.cachedAccount;
        return HomeTopBar(
          centerTitle: title,
          showUnreadDot: notificationsRepo.unread.count > 0,
          onAddBabyTap: () => context.push('/baby/create'),
          onInviteFamilyTap: () => onShellInviteFamilyTap(context),
          onBabySwitcherTap: () => showBabySwitcherSheet(context),
          onNotificationsTap: () async {
            await context.push('/notifications/inbox');
            try {
              await notificationsRepo.refreshUnreadCount();
            } catch (e) {
              debugPrint('shell_top_bar_unread_refresh_failed: $e');
            }
          },
          onAccountTap: () => context.push('/profile'),
          accountDisplayName: account?.displayName,
          accountAvatarUrl: account?.avatarUrl,
        );
      },
    );
  }
}
