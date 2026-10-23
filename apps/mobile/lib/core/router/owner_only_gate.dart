import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../widgets/app_snackbar.dart';
import 'subpage_navigation.dart';

/// Route-level guard for owner-only pages (create/edit forms, shipping
/// address, AI suggestions, followers, announcement create).
///
/// Every owner-only route in `app_router.dart` builds its screen through this
/// gate, so a follower who reaches one (a stale button, a deep link, a
/// redirect) is turned away before the form is shown instead of each screen
/// checking the role itself. The API enforces the same rule.
///
/// The baby is the route's `:babyId` when [babyId] is set, otherwise the
/// selected baby (tab routes). Only a known non-owner role is blocked: when the
/// baby cannot be resolved (offline with no cache) the screen's own load
/// handles it.
class OwnerOnlyGate extends StatefulWidget {
  const OwnerOnlyGate({
    super.key,
    this.babyId,
    required this.fallbackLocation,
    required this.child,
  });

  final String? babyId;

  /// Where to go when the page was opened with nothing to pop back to.
  final String fallbackLocation;

  final Widget child;

  @override
  State<OwnerOnlyGate> createState() => _OwnerOnlyGateState();
}

class _OwnerOnlyGateState extends State<OwnerOnlyGate> {
  var _allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final home = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    String? role;
    try {
      final id = widget.babyId;
      final baby = id != null
          ? await home.babyById(id)
          : await home.resolveSelectedBaby(store);
      role = baby?.role;
    } catch (_) {
      role = null;
    }
    if (!mounted) return;
    if (role == null || role == 'owner') {
      setState(() => _allowed = true);
      return;
    }
    AppSnackBar.showAlert(
      context,
      AppLocalizations.of(context)!.ownerOnlyPageBlocked,
    );
    popOrGo(context, widget.fallbackLocation);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) return widget.child;
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
