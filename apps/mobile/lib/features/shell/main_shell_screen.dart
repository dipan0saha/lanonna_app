import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_semantics.dart';
import '../home/data/home_refresh_signal.dart';
import 'shell_branch_index.dart';
import '../../l10n/app_localizations.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    if (index == ShellBranchIndex.home) {
      context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
    }
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        key: const Key('app_bottom_nav_bar'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: [
          NavigationDestination(
            icon: AppSemantics.button('nav_home', const Icon(Icons.home_outlined)),
            selectedIcon: AppSemantics.button('nav_home', const Icon(Icons.home)),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: AppSemantics.button('nav_gallery', const Icon(Icons.photo_library_outlined)),
            selectedIcon: AppSemantics.button('nav_gallery', const Icon(Icons.photo_library)),
            label: l10n.notificationChannelGallery,
          ),
          NavigationDestination(
            icon: AppSemantics.button('nav_calendar', const Icon(Icons.calendar_today_outlined)),
            selectedIcon: AppSemantics.button('nav_calendar', const Icon(Icons.calendar_today)),
            label: l10n.calendarTitle,
          ),
          NavigationDestination(
            icon: AppSemantics.button('nav_registry', const Icon(Icons.card_giftcard_outlined)),
            selectedIcon: AppSemantics.button('nav_registry', const Icon(Icons.card_giftcard)),
            label: l10n.notificationChannelRegistry,
          ),
          NavigationDestination(
            icon: AppSemantics.button('nav_fun', const Icon(Icons.auto_awesome_outlined)),
            selectedIcon: AppSemantics.button('nav_fun', const Icon(Icons.auto_awesome)),
            label: l10n.navFun,
          ),
        ],
      ),
    );
  }
}
