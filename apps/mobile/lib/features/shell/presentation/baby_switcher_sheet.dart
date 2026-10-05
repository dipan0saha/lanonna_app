import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/domain/baby_list_subtitle.dart';

Future<void> showBabySwitcherSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _BabySwitcherSheetBody(),
  );
}

class _BabySwitcherSheetBody extends StatefulWidget {
  const _BabySwitcherSheetBody();

  @override
  State<_BabySwitcherSheetBody> createState() => _BabySwitcherSheetBodyState();
}

class _BabySwitcherSheetBodyState extends State<_BabySwitcherSheetBody> {
  List<BabySummary> _babies = [];
  String? _highlightedId;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final babies = await homeRepo.listBabies();
      final resolved = await homeRepo.resolveSelectedBaby(store);
      setState(() {
        _babies = babies;
        _highlightedId = resolved?.id;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _select(BabySummary baby) async {
    await context.read<SelectedBabyStore>().setSelectedBabyId(baby.id);
    if (mounted) {
      context.read<HomeRefreshSignal>().notifyBabyContextChanged();
      Navigator.of(context).pop();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = _highlightedId;
    final styles = context.textStyles;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Switch baby', style: styles.titleMedium),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_babies.isEmpty)
            const Text('No baby profiles yet.')
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final baby in _babies)
                    AppSemantics.button(
                      'baby_switcher_${baby.id.replaceAll('-', '_')}',
                      ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.sageTint,
                        child: Text(
                          baby.name.isNotEmpty ? baby.name[0].toUpperCase() : '?',
                          style: styles.titleSmall,
                        ),
                      ),
                      title: Text(baby.name),
                      subtitle: Text(babyListSubtitle(baby)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (baby.id == selectedId)
                            const Icon(Icons.check, color: AppColors.primaryDark),
                          if (baby.role == 'owner')
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (value) {
                                Navigator.of(context).pop();
                                if (value == 'edit') {
                                  context.push('/baby/${baby.id}/edit');
                                } else if (value == 'followers') {
                                  context.push('/baby/${baby.id}/followers');
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit baby')),
                                PopupMenuItem(
                                  value: 'followers',
                                  child: Text('Manage followers'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      onTap: () => _select(baby),
                    ),
                    ),
                ],
              ),
            ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Account'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add New Baby'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/baby/create');
            },
          ),
        ],
      ),
    );
  }
}
