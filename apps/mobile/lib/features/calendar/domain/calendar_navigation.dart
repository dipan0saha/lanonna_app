import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shell/shell_branch_index.dart';
import 'calendar_routes.dart';

/// Leaves event detail/edit flows and returns to the calendar tab root.
void returnToCalendar(BuildContext context) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(ShellBranchIndex.calendar, initialLocation: true);
  } else {
    context.go(CalendarRoutes.calendar);
  }
}
