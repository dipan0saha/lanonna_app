import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/domain/app_routes.dart';

/// Pop the current route, or open Home when this page is the only entry.
///
/// Subpages are pushed on the root navigator. A bare [GoRouter.go] can leave
/// one of them with nothing to pop, which throws and lets system Back exit
/// the app. Every subpage back button and system Back should use this.
void popOrGoHome(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(AppRoutes.home);
    return;
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
}
