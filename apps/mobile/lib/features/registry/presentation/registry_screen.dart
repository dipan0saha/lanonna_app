import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../../shell/presentation/shell_tab_layout.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/models/registry_models.dart';
import '../data/registry_repository.dart';
import '../domain/registry_routes.dart';
import 'widgets/registry_empty_state.dart';
import 'widgets/registry_item_row.dart';

class RegistryScreen extends StatefulWidget {
  const RegistryScreen({super.key});

  @override
  State<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends State<RegistryScreen> with BabyContextReload {
  BabySummary? _baby;
  List<RegistryItem> _items = [];
  RegistryShippingAddress? _shipping;
  var _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
  }

  @override
  void dispose() {
    disposeBabyContextListeners();
    super.dispose();
  }

  @override
  void onBabyContextReload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final homeRepo = context.read<HomeRepository>();
      final regRepo = context.read<RegistryRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() {
          _baby = null;
          _loading = false;
        });
        return;
      }
      final items = await regRepo.listItems(baby.id);
      final shipping = await regRepo.getShippingAddress(baby.id);
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _items = items;
        _shipping = shipping;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  List<RegistryItem> get _needed =>
      _items.where((i) => !i.isPurchased).toList();

  List<RegistryItem> get _purchased =>
      _items.where((i) => i.isPurchased).toList();

  Future<void> _openShippingEditor() async {
    final changed = await context.push<bool>(RegistryRoutes.shippingAddress);
    if (changed == true) await _load();
  }

  Widget _shippingSection() {
    final shipping = _shipping;
    final hasAddress = shipping != null && !shipping.isEmpty;
    if (!_isOwner && !hasAddress) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                'Shipping Address',
                style: context.textStyles.labelLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              if (_isOwner)
                TextButton(
                  onPressed: _openShippingEditor,
                  child: Text(hasAddress ? 'Edit' : 'Add shipping address'),
                ),
            ],
          ),
        ),
        if (hasAddress)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  shipping.formatted ?? '',
                  style: context.textStyles.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
          )
        else if (_isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Add an address so family knows where to send gifts.',
              style: context.textStyles.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _claim(RegistryItem item) async {
    final baby = _baby;
    if (baby == null) return;
    if (_isOwner) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mark as purchased?'),
          content: const Text(
            'Family will see this item as taken so no one buys it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark as purchased'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    final ok = await runMutation(
      context,
      () => context.read<RegistryRepository>().claimPurchase(baby.id, item.id),
    );
    if (!ok || !mounted) return;
    await _load();
  }

  Future<void> _undo(RegistryItem item) async {
    final baby = _baby;
    if (baby == null) return;
    final ok = await runMutation(
      context,
      () => context.read<RegistryRepository>().undoPurchase(baby.id, item.id),
    );
    if (!ok || !mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthRepository>().currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShellTabLayout(
        onRefresh: _load,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppMetrics.horizontalPadding,
                    0,
                    AppMetrics.horizontalPadding,
                    8,
                  ),
                  child: Text('Registry', style: context.textStyles.headlineSmall),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadError != null)
                SliverFillRemaining(
                  child: AsyncTabBody(
                    loading: false,
                    error: _loadError,
                    onRetry: _load,
                    child: const SizedBox.shrink(),
                  ),
                )
              else if (_baby == null)
                const SliverFillRemaining(
                  child: Center(child: Text('No baby profile yet.')),
                )
              else ...[
                if (_isOwner)
                  SliverToBoxAdapter(
                    child: _AiBanner(
                      onTap: () => context.push(RegistryRoutes.aiSuggestions),
                    ),
                  ),
                SliverToBoxAdapter(child: _shippingSection()),
                if (_items.isEmpty)
                  SliverFillRemaining(
                    child: RegistryEmptyState(
                      isOwner: _isOwner,
                      onAddItem: _isOwner
                          ? () => context.push(RegistryRoutes.createItem)
                          : null,
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: AppSectionTitle(
                        title: 'Needed',
                        action: Text(
                          'Priority: High first',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _needed.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('All caught up!'),
                              )
                            : Column(
                                children: [
                                  for (final item in _needed)
                                    RegistryNeededRow(
                                      item: item,
                                      isOwner: _isOwner,
                                      currentUid: uid,
                                      onClaim: () => _claim(item),
                                      onEdit: () => context.push(
                                        RegistryRoutes.itemEdit(item.id),
                                      ),
                                      onDelete: () async {
                                        await context
                                            .read<RegistryRepository>()
                                            .deleteItem(_baby!.id, item.id);
                                        await _load();
                                      },
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        AppMetrics.sectionBlockSpacing,
                        16,
                        0,
                      ),
                      child: const AppSectionTitle(title: 'Purchased'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _purchased.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Nothing purchased yet.'),
                              )
                            : Column(
                                children: [
                                  for (final item in _purchased)
                                    RegistryPurchasedRow(
                                      item: item,
                                      canUndo: _isOwner ||
                                          item.purchase?.purchasedByFirebaseUid == uid,
                                      onUndo: () => _undo(item),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      floatingActionButton: _isOwner && _baby != null && _items.isNotEmpty
          ? AppSemantics.button(
              'registry_create_fab',
              FloatingActionButton(
                onPressed: () => context.push(RegistryRoutes.createItem),
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.peachTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Not sure where to start? See AI-suggested items by stage and age.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
