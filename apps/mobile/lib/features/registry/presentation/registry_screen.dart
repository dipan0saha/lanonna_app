import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
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
import 'delete_registry_item_flow.dart';
import 'widgets/registry_empty_state.dart';
import 'widgets/registry_item_row.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/data/parallel_requests.dart';

class RegistryScreen extends StatefulWidget {
  const RegistryScreen({super.key});

  @override
  State<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends State<RegistryScreen>
    with BabyContextReload, TabLoadGenerationCache {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
    if (shouldShowTabLoadSpinner(
      store,
      hasDisplayedPayload: hasCurrentTabPayload(store, _baby?.id),
    )) {
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
      final (items, shipping) = await waitBoth(
        regRepo.listItems(baby.id),
        regRepo.getShippingAddress(baby.id),
      );
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
      final hasPayload = hasCurrentTabPayload(store, _baby?.id);
      if (!hasPayload) {
        setState(() {
          _baby = null;
          _items = [];
          _shipping = null;
        });
      }
      reportTabLoadFailure(
        context,
        e,
        hasPayload: hasPayload,
        onBlockingError: (message) {
          setState(() {
            _loadError = message;
            _loading = false;
          });
        },
      );
      if (hasPayload && mounted) {
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
              AppSectionCapsLabel(l10n.shippingAddressTitle),
              const Spacer(),
              if (_isOwner)
                TextButton(
                  onPressed: _openShippingEditor,
                  child: Text(hasAddress ? l10n.actionEdit : l10n.actionAdd),
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
              l10n.actionAddAddressKnows,
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
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.registryMarkPurchasedTitle,
        message: l10n.messageItem,
        confirmLabel: l10n.registryMarkPurchased,
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

  Future<void> _deleteItem(RegistryItem item) async {
    final baby = _baby;
    if (baby == null) return;
    final deleted = await deleteRegistryItemWithConfirmation(
      context,
      babyId: baby.id,
      itemId: item.id,
    );
    if (!deleted || !mounted) return;
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
    final l10n = AppLocalizations.of(context)!;
    final uid = context.read<AuthRepository>().currentUser?.uid;
    final store = context.read<SelectedBabyStore>();
    final kind = resolveTabLoadKind(
      loading: _loading,
      hasError: _loadError != null,
      hasPayload: hasCurrentTabPayload(store, _baby?.id),
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
                  l10n.notificationChannelRegistry,
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
              SliverFillRemaining(
                child: Center(child: Text(AppLocalizations.of(context)!.noBabyProfileYet)),
              )
            else ...[
              if (_isOwner)
                SliverToBoxAdapter(
                  child: CalendarAiSuggestionBanner(
                    message:
                        l10n.hintSureStart2,
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
                      title: l10n.registrySectionNeeded,
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
                          ? Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(AppLocalizations.of(context)!.registryAllCaughtUp),
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
                                    onDelete: () => _deleteItem(item),
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
                    child: AppSectionTitle(title: l10n.registrySectionPurchased),
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
                          ? Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(AppLocalizations.of(context)!.registryNothingPurchased),
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
                tooltip: l10n.registryAddItem,
                onPressed: () => context.push(RegistryRoutes.createItem),
                child: const ExcludeSemantics(child: Icon(Icons.add)),
              ),
              label: l10n.registryAddItem,
            )
          : null,
    );
  }
}
