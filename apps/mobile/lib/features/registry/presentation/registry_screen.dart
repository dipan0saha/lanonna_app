import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
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

class _RegistryScreenState extends State<RegistryScreen> {
  BabySummary? _baby;
  List<RegistryItem> _items = [];
  String? _shippingAddress;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      final address = await regRepo.getShippingAddress(baby.id);
      setState(() {
        _baby = baby;
        _items = items;
        _shippingAddress = address;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  List<RegistryItem> get _needed =>
      _items.where((i) => !i.isPurchased).toList();

  List<RegistryItem> get _purchased =>
      _items.where((i) => i.isPurchased).toList();

  Future<void> _editShipping() async {
    final baby = _baby;
    if (baby == null || !_isOwner) return;
    final controller = TextEditingController(text: _shippingAddress ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shipping address'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Address for gifts'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await context.read<RegistryRepository>().updateShippingAddress(
      baby.id,
      controller.text.trim().isEmpty ? null : controller.text.trim(),
    );
    await _load();
  }

  Future<void> _claim(RegistryItem item) async {
    final baby = _baby;
    if (baby == null) return;
    await context.read<RegistryRepository>().claimPurchase(baby.id, item.id);
    await _load();
  }

  Future<void> _undo(RegistryItem item) async {
    final baby = _baby;
    if (baby == null) return;
    await context.read<RegistryRepository>().undoPurchase(baby.id, item.id);
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
                  if (_shippingAddress != null || _isOwner)
                    SliverToBoxAdapter(
                      child: Padding(
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
                              TextButton(onPressed: _editShipping, child: const Text('Edit')),
                          ],
                        ),
                      ),
                    ),
                  if (_shippingAddress != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(_shippingAddress!),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text('Needed', style: context.textStyles.labelLarge),
                          const Spacer(),
                          Text(
                            'Priority: High first',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
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
                                      onBuy: () => _claim(item),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Purchased', style: context.textStyles.labelLarge),
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
          ? FloatingActionButton(
              onPressed: () => context.push(RegistryRoutes.createItem),
              child: const Icon(Icons.add),
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
                  'Not sure where to start? See AI-suggested items by age range.',
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
