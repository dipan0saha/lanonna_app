import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shell/shell_branch_index.dart';
import 'gallery_routes.dart';

/// Leaves photo detail and returns to the gallery tab root.
void returnToGallery(BuildContext context) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(ShellBranchIndex.gallery, initialLocation: true);
  } else {
    context.go(GalleryRoutes.gallery);
  }
}
