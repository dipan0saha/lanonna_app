import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/widgets/app_labeled_text_form_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/registry_repository.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../l10n/app_localizations.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _link = TextEditingController();
  var _priority = 3;
  BabySummary? _baby;
  var _saving = false;
  var _validateOnInteraction = false;

  AutovalidateMode get _autovalidateMode => _validateOnInteraction
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

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
    if (!mounted) return;
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
    if (baby == null) return;
    setState(() => _validateOnInteraction = true);
    if (_formKey.currentState?.validate() != true) return;

    final name = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _name.text,
    );
    final description = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _desc.text,
    );
    final productUrl = normalizeOptionalHttpUrl(_link.text);

    setState(() => _saving = true);
    final repo = context.read<RegistryRepository>();
    final ok = await runMutation(context, () async {
      if (widget.isEdit) {
        await repo.updateItem(
          baby.id,
          widget.itemId!,
          name: name,
          description: description.isEmpty ? null : description,
          productUrl: productUrl,
          priority: _priority,
        );
      } else {
        await repo.createItem(
          baby.id,
          name: name,
          description: description.isEmpty ? null : description,
          productUrl: productUrl,
          priority: _priority,
          catalogSuggestionId: widget.initialCatalogSuggestionId,
        );
      }
    });
    if (mounted) setState(() => _saving = false);
    if (!ok || !mounted) return;
    context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
    context.pop(!widget.isEdit);
  }

  Future<void> _delete() async {
    final baby = _baby;
    if (baby == null || !widget.isEdit) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.registryDeleteConfirmTitle,
      message: l10n.messageRemoves,
      confirmLabel: l10n.actionDelete,
      variant: ConfirmDialogVariant.destructive,
    );
    if (confirmed != true || !mounted) return;
    final ok = await runMutation(
      context,
      () => context.read<RegistryRepository>().deleteItem(
        baby.id,
        widget.itemId!,
      ),
    );
    if (!ok || !mounted) return;
    context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mutedCaption = context.textStyles.bodySmall?.copyWith(
      fontSize: 10.5,
      color: AppColors.muted,
    );

    return PrototypeSubpageScaffold(
      title: widget.isEdit ? AppLocalizations.of(context)!.registryEditRegistryItem : AppLocalizations.of(context)!.registryAddRegistryItem,
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: AppMetrics.subpageFormScrollPadding,
          children: [
            AppLabeledTextFormField(
              semanticsId: 'registry_item_name',
              label: l10n.fieldItemName,
              hint: l10n.labelEGCribMattress,
              kind: AppTextInputKind.prose,
              controller: _name,
              validator: (v) => validateRegistryItemName(AppLocalizations.of(context)!, v),
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextField(
              label: l10n.fieldDescriptionOptional,
              hint: l10n.hintStandardSizeGreenguardGoldCertified,
              kind: AppTextInputKind.prose,
              controller: _desc,
              maxLines: 3,
              minLines: 3,
            ),
            AppLabeledTextFormField(
              label: l10n.fieldLinkOptional,
              hint: l10n.hintPasteLinkItem,
              kind: AppTextInputKind.none,
              controller: _link,
              keyboardType: TextInputType.url,
              validator: (v) => validateOptionalHttpUrl(AppLocalizations.of(context)!, v),
              autovalidateMode: _autovalidateMode,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.registryPriorityLabel, style: context.fieldLabelStyle),
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
                      Text(AppLocalizations.of(context)!.registryPriorityLow, style: mutedCaption),
                      Text(AppLocalizations.of(context)!.registryPriorityHigh, style: mutedCaption),
                    ],
                  ),
                ],
              ),
            ),
            AppSemantics.button(
              'registry_item_save',
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.isEdit ? AppLocalizations.of(context)!.calendarSaveChanges : AppLocalizations.of(context)!.registryAddItemTitle),
              ),
              label: l10n.registryAddItemTitle,
            ),
            if (widget.isEdit) ...[
              const SizedBox(height: AppMetrics.formFieldSpacing - 4),
              OutlinedButton(
                onPressed: _delete,
                style: AppButtonStyles.outlinedDestructive,
                child: Text(AppLocalizations.of(context)!.registryDeleteItem),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
