import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/widgets/app_text_form_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/fun_repository.dart';
import '../data/models/fun_models.dart';

class NamesTab extends StatefulWidget {
  const NamesTab({super.key, required this.baby, this.readOnly = false});

  final BabySummary baby;
  final bool readOnly;

  @override
  State<NamesTab> createState() => _NamesTabState();
}

class _NamesTabState extends State<NamesTab> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  final _suggestFormKey = GlobalKey<FormState>();
  NamesPayload? _payload;
  final _input = TextEditingController();
  var _gender = 'male';
  var _loading = true;
  String? _error;
  var _validateSuggestOnInteraction = false;

  bool get _isOwner => widget.baby.role == 'owner';

  bool get _readOnly => widget.readOnly;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NamesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Baby switch reuses this State (same tab position): drop the previous
    // baby's suggestions and draft, then load for the new baby.
    if (oldWidget.baby.id != widget.baby.id) {
      _payload = null;
      _input.clear();
      _validateSuggestOnInteraction = false;
      _load();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final babyId = widget.baby.id;
    try {
      final payload = await context.read<FunRepository>().fetchNames(babyId);
      // Ignore a response for a baby that is no longer shown.
      if (!mounted || babyId != widget.baby.id) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || babyId != widget.baby.id) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _validateSuggestOnInteraction = true);
    if (_suggestFormKey.currentState?.validate() != true) return;

    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _input.text,
    );
    final ok = await runMutation(
      context,
      () => context.read<FunRepository>().suggestName(
        widget.baby.id,
        text,
        _gender,
      ),
    );
    if (!ok) return;
    _input.clear();
    await _load();
  }

  Future<void> _like(NameSuggestion s) async {
    final ok = await runMutation(
      context,
      () => context.read<FunRepository>().toggleLike(widget.baby.id, s.id),
    );
    if (!ok) return;
    await _load();
  }

  Future<void> _delete(NameSuggestion s) async {
    if (!s.canDelete) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.funRemoveNameTitle),
        content: Text(
          AppLocalizations.of(ctx)!.funRemoveNameBody(s.suggestedName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.actionRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final removed = await runMutation(
      context,
      () =>
          context.read<FunRepository>().deleteSuggestion(widget.baby.id, s.id),
    );
    if (!removed) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncTabBody(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final payload = _payload;
    final suggestions = payload?.suggestions ?? [];
    if (suggestions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppEmptyState(
              expand: false,
              icon: Icons.star_outline,
              title: l10n.emptyNameSuggestionsYet,
              message: _readOnly
                  ? 'No name ideas were saved before baby arrived.'
                  : 'Suggest a name below — everyone gets a say.',
            ),
            if (!_readOnly) _inputCard(),
          ],
        ),
      );
    }
    final boys = suggestions.where((s) => s.gender == 'male').toList();
    final girls = suggestions.where((s) => s.gender == 'female').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          16,
          AppMetrics.horizontalPadding,
          16,
        ),
        children: [
          if (_readOnly)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                AppLocalizations.of(context)!.namesClosedNote,
                style: context.textStyles.bodyMedium,
              ),
            ),
          if (!_readOnly) _inputCard(),
          if (!_readOnly) const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _column('Boys', boys)),
              const SizedBox(width: 12),
              Expanded(child: _column('Girls', girls)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    final autovalidate = _validateSuggestOnInteraction
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _suggestFormKey,
          autovalidateMode: autovalidate,
          child: Column(
            children: [
              AppTextFormField(
                kind: AppTextInputKind.personName,
                controller: _input,
                decoration: InputDecoration(hintText: l10n.labelSuggestName2),
                validator: validateFunNameSuggestion,
                autovalidateMode: autovalidate,
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'male',
                          label: Text(
                            BabyGender.male.label(AppLocalizations.of(context)!),
                          ),
                        ),
                        ButtonSegment(
                          value: 'female',
                          label: Text(
                            BabyGender.female.label(AppLocalizations.of(context)!),
                          ),
                        ),
                      ],
                      selected: {_gender},
                      onSelectionChanged: (s) =>
                          setState(() => _gender = s.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(AppLocalizations.of(context)!.actionAdd),
                  ),
                ],
              ),
              if (!_isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.messageSuggestName,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _column(String title, List<NameSuggestion> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: title == 'Boys'
                    ? AppColors.primaryDark
                    : AppColors.secondaryDark,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(title, style: context.textStyles.labelLarge),
          ],
        ),
        for (final s in list)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _NameSuggestionCard(
              suggestion: s,
              readOnly: _readOnly,
              onLike: _readOnly ? null : () => _like(s),
              onDelete: _readOnly ? null : () => _delete(s),
            ),
          ),
      ],
    );
  }
}

/// Full-width card for narrow Boys/Girls columns (avoids [ListTile] trailing squeeze).
class _NameSuggestionCard extends StatelessWidget {
  const _NameSuggestionCard({
    required this.suggestion,
    this.readOnly = false,
    required this.onLike,
    required this.onDelete,
  });

  final NameSuggestion suggestion;
  final bool readOnly;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              suggestion.suggestedName,
              style: styles.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              suggestion.authorDisplayName,
              style: styles.bodySmall?.copyWith(color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!readOnly)
                  AppIconButton(
                    semanticsId: 'name_like_${suggestion.id}',
                    label: suggestion.viewerHasLiked
                        ? 'Unlike ${suggestion.suggestedName}'
                        : 'Love ${suggestion.suggestedName}',
                    onPressed: onLike,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      suggestion.viewerHasLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: suggestion.viewerHasLiked
                          ? AppColors.primaryDark
                          : null,
                    ),
                  )
                else if (suggestion.viewerHasLiked)
                  Icon(Icons.favorite, size: 20, color: AppColors.primaryDark),
                Semantics(
                  label: l10n.nameLoveCount(suggestion.likeCount),
                  child: Text(
                    '${suggestion.likeCount}',
                    style: styles.labelMedium,
                  ),
                ),
                if (!readOnly && suggestion.canDelete)
                  AppIconButton(
                    semanticsId: 'name_remove_${suggestion.id}',
                    label: AppLocalizations.of(
                      context,
                    )!.funRemoveNameSemantics(suggestion.suggestedName),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
