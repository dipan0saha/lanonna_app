import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/domain/app_routes.dart';

/// Pop the current route, or go to [fallback] when this page is the only entry.
///
/// Subpages are pushed on the root navigator, so popping returns to whichever
/// screen opened them (a tab, Home, the Inbox, the activity feed). A page
/// reached by a bare [GoRouter.go] can have nothing to pop, which throws and
/// lets system Back exit the app; [fallback] covers that case.
void popOrGo(BuildContext context, String fallback) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(fallback);
    return;
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

/// [popOrGo] with Home as the fallback. Every subpage back button and system
/// Back use this.
void popOrGoHome(BuildContext context) => popOrGo(context, AppRoutes.home);
