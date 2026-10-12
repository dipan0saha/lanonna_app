import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../comments/comment_composer_controller.dart';

/// Shared loading UX for baby-scoped detail screens (photo, event, etc.).
bool shouldShowDetailFullScreenLoader({
  required bool hasContent,
  required bool initialLoadInFlight,
}) {
  return !hasContent && initialLoadInFlight;
}

/// Push a sub-route, then return focus to the detail screen without the keyboard.
///
/// Unfocus runs before the push and again after every pop (Save and Back).
/// [refresh] runs only when [shouldRefresh] returns true.
Future<T?> pushAndRefresh<T>(
  BuildContext context,
  String location, {
  required CommentComposerController composer,
  required Future<void> Function() refresh,
  bool Function(T? result)? shouldRefresh,
  Object? extra,
}) async {
  composer.unfocus();
  final result = await context.push<T>(location, extra: extra);
  if (!context.mounted) return result;
  composer.unfocus();
  if (shouldRefresh?.call(result) ?? false) {
    await refresh();
  }
  return result;
}
