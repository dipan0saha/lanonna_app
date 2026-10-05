import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/input/app_text_input_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/registry_repository.dart';

class RegistryItemFormPrefill {
  RegistryItemFormPrefill({
    required this.name,
    this.description,
    this.catalogSuggestionId,
  });

  final String name;
  final String? description;
  final String? catalogSuggestionId;
}

class RegistryItemFormScreen extends StatefulWidget {
  const RegistryItemFormScreen({
    super.key,
    this.itemId,
    this.initialName,
    this.initialDescription,
    this.initialCatalogSuggestionId,
  });

  final String? itemId;
  final String? initialName;
  final String? initialDescription;
  final String? initialCatalogSuggestionId;

  bool get isEdit => itemId != null;

  @override
  State<RegistryItemFormScreen> createState() => _RegistryItemFormScreenState();
}

class _RegistryItemFormScreenState extends State<RegistryItemFormScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _link = TextEditingController();
  var _priority = 3;
  BabySummary? _baby;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    _desc.text = widget.initialDescription ?? '';
    _loadBaby();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _loadBaby() async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    setState(() => _baby = baby);
    if (widget.isEdit && baby != null) {
      final items = await context.read<RegistryRepository>().listItems(baby.id);
      final item = items.where((i) => i.id == widget.itemId).firstOrNull;
      if (item != null) {
        _name.text = item.name;
        _desc.text = item.description ?? '';
        _link.text = item.productUrl ?? '';
        _priority = item.priority;
        setState(() {});
      }
    }
  }

  Future<void> _save() async {
    final baby = _baby;
    final name = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _name.text,
    );
    if (baby == null || name.isEmpty) return;
    final description = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _desc.text,
    );
    final productUrl = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.none,
      _link.text,
    );
    setState(() => _saving = true);
    try {
      final repo = context.read<RegistryRepository>();
      if (widget.isEdit) {
        await repo.updateItem(
          baby.id,
          widget.itemId!,
          name: name,
          description: description.isEmpty ? null : description,
          productUrl: productUrl.isEmpty ? null : productUrl,
          priority: _priority,
        );
      } else {
        await repo.createItem(
          baby.id,
          name: name,
          description: description.isEmpty ? null : description,
          productUrl: productUrl.isEmpty ? null : productUrl,
          priority: _priority,
          catalogSuggestionId: widget.initialCatalogSuggestionId,
        );
      }
      if (mounted) {
        context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
        context.pop(!widget.isEdit);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, 'Save failed: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final baby = _baby;
    if (baby == null || !widget.isEdit) return;
    await context.read<RegistryRepository>().deleteItem(baby.id, widget.itemId!);
    if (mounted) {
      context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutedCaption = context.textStyles.bodySmall?.copyWith(
      fontSize: 10.5,
      color: AppColors.muted,
    );

    return PrototypeSubpageScaffold(
      title: widget.isEdit ? 'Edit Registry Item' : 'Add Registry Item',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          0,
          AppMetrics.horizontalPadding,
          96,
        ),
        children: [
          AppLabeledTextField(
            semanticsId: 'registry_item_name',
            label: 'Item Name',
            hint: 'e.g. Crib & Mattress',
            kind: AppTextInputKind.prose,
            controller: _name,
          ),
          AppLabeledTextField(
            label: 'Description (optional)',
            hint: 'Standard size, GREENGUARD Gold certified…',
            kind: AppTextInputKind.prose,
            controller: _desc,
            maxLines: 3,
            minLines: 3,
          ),
          AppLabeledTextField(
            label: 'Link (optional)',
            hint: 'Paste a link to the item',
            kind: AppTextInputKind.none,
            controller: _link,
            keyboardType: TextInputType.url,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Priority', style: context.fieldLabelStyle),
                    Text(
                      '$_priority',
                      style: context.textStyles.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _priority.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_priority',
                  activeColor: AppColors.primaryDark,
                  onChanged: (v) => setState(() => _priority = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nice to have', style: mutedCaption),
                    Text('Really need this', style: mutedCaption),
                  ],
                ),
              ],
            ),
          ),
          AppSemantics.button(
            'registry_item_save',
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.isEdit ? 'Save Changes' : 'Add Item'),
            ),
            label: 'Add Item',
          ),
          if (widget.isEdit) ...[
            const SizedBox(height: AppMetrics.formFieldSpacing - 4),
            OutlinedButton(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete Item'),
            ),
          ],
        ],
      ),
    );
  }
}
