import 'package:flutter/material.dart';

import '../../home/presentation/widgets/home_top_bar.dart';
import 'baby_switcher_sheet.dart';

HomeTopBar shellHomeTopBar(BuildContext context) {
  return HomeTopBar(
    onProfileTap: () => showBabySwitcherSheet(context),
    onSearchTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search coming soon')),
      );
    },
    onNotificationsTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications coming soon')),
      );
    },
  );
}
