import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/presentation/tab_load_kind.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_section_caps_label.dart';
import '../../../core/widgets/app_bordered_surface.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/calendar_ai_suggestion_banner.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../domain/registry_item_sort.dart';
import 'widgets/registry_sort_control.dart';
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

class _RegistryScreenState extends State<RegistryScreen>
    with BabyContextReload, TabLoadGenerationCache {
  BabySummary? _baby;
  List<RegistryItem> _items = [];
  RegistryShippingAddress? _shipping;
  var _loading = true;
  String? _loadError;
  RegistryItemSort _neededSort = RegistryItemSort.priorityHighFirst;

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
    final store = context.read<SelectedBabyStore>();
    if (shouldShowTabLoadSpinner(store, hasDisplayedPayload: _baby != null)) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final homeRepo = context.read<HomeRepository>();
      final regRepo = context.read<RegistryRepository>();
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
      rememberTabLoadGeneration(store, baby);
    } catch (e) {
      if (!mounted) return;
      final hadBaby = _baby != null;
      reportTabLoadFailure(
        context,
        e,
        hasPayload: hadBaby,
        onBlockingError: (message) {
          setState(() {
            _loadError = message;
            _loading = false;
          });
        },
      );
      if (hadBaby && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  List<RegistryItem> get _needed =>
      sortRegistryItems(
        _items.where((i) => !i.isPurchased).toList(),
        _neededSort,
      );

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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        AppSpacing.sm,
        AppMetrics.horizontalPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppSectionCapsLabel('Shipping address'),
              const Spacer(),
              if (_isOwner)
                TextButton(
                  onPressed: _openShippingEditor,
                  child: Text(hasAddress ? 'Edit' : 'Add'),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          if (hasAddress)
            AppBorderedSurface(
              child: Padding(
                padding: AppMetrics.borderedListRowPadding,
                child: Text(
                  shipping.formatted ?? '',
                  style: context.textStyles.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            )
          else if (_isOwner)
            Text(
              'Add an address so family knows where to send gifts.',
              style: context.textStyles.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
        ],
      ),
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
    final kind = resolveTabLoadKind(
      loading: _loading,
      hasError: _loadError != null,
      hasPayload: _baby != null,
    );
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
                child: Text(
                  'Registry',
                  style: context.textStyles.headlineSmall,
                ),
              ),
            ),
            if (kind == TabLoadKind.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (kind == TabLoadKind.error)
              SliverFillRemaining(
                child: AsyncTabBody(
                  loading: false,
                  error: _loadError,
                  onRetry: _load,
                  child: const SizedBox.shrink(),
                ),
              )
            else if (kind == TabLoadKind.empty)
              const SliverFillRemaining(
                child: Center(child: Text('No baby profile yet.')),
              )
            else ...[
              if (_isOwner)
                SliverToBoxAdapter(
                  child: CalendarAiSuggestionBanner(
                    message:
                        'Not sure where to start? See AI-suggested items by stage and age.',
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
                    padding: const EdgeInsets.fromLTRB(
                      AppMetrics.horizontalPadding,
                      12,
                      AppMetrics.horizontalPadding,
                      0,
                    ),
                    child: AppSectionTitle(
                      title: 'Needed',
                      action: RegistrySortControl(
                        sort: _neededSort,
                        onChanged: (sort) => setState(() => _neededSort = sort),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppMetrics.horizontalPadding,
                    ),
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
                                      final baby = _baby;
                                      if (baby == null) return;
                                      final ok = await runMutation(
                                        context,
                                        () => context
                                            .read<RegistryRepository>()
                                            .deleteItem(baby.id, item.id),
                                      );
                                      if (!ok || !mounted) return;
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
                      AppMetrics.horizontalPadding,
                      AppMetrics.sectionBlockSpacing,
                      AppMetrics.horizontalPadding,
                      0,
                    ),
                    child: const AppSectionTitle(title: 'Purchased'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(
                      AppMetrics.horizontalPadding,
                      0,
                      AppMetrics.horizontalPadding,
                      96,
                    ),
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
                                    canUndo:
                                        _isOwner ||
                                        item.purchase?.purchasedByFirebaseUid ==
                                            uid,
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
                tooltip: 'Add item',
                onPressed: () => context.push(RegistryRoutes.createItem),
                child: const ExcludeSemantics(child: Icon(Icons.add)),
              ),
              label: 'Add item',
            )
          : null,
    );
  }
}
