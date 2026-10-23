import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/person_display_label.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/widgets/baby_gender_chip_bar.dart';
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
  var _gender = BabyGender.male;
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

  /// The spinner shows only while nothing is on screen; reloads after a
  /// change (like, suggest, remove, pull-to-refresh) keep the list and its
  /// scroll position, and a failed reload is a snackbar.
  Future<void> _load() async {
    final hadPayload = _payload != null;
    if (!hadPayload) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
      reportTabLoadFailure(
        context,
        e,
        hasPayload: _payload != null,
        onBlockingError: (message) => setState(() {
          _loading = false;
          _error = message;
        }),
      );
      if (_payload != null) setState(() => _loading = false);
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
    if (!ok || !mounted) return;
    _resetSuggestForm();
    await _load();
  }

  /// After a successful suggest (#397). Clearing the controller alone counts
  /// as an edit, so with validation on it flagged the now-empty field as
  /// "Name is required". [FormState.reset] empties the field and forgets that
  /// interaction, and validation waits for the next submit again.
  void _resetSuggestForm() {
    _suggestFormKey.currentState?.reset();
    setState(() => _validateSuggestOnInteraction = false);
  }

  Future<void> _like(NameSuggestion s) async {
    final before = _payload;
    if (before == null) return;
    final optimistic = before.withLikeToggled(s.id);
    final ok = await runOptimisticMutation(
      context,
      apply: () => setState(() => _payload = optimistic),
      revert: () {
        if (mounted && identical(_payload, optimistic)) {
          setState(() => _payload = before);
        }
      },
      action: () async {
        await context.read<FunRepository>().toggleLike(widget.baby.id, s.id);
      },
    );
    if (!ok || !mounted) return;
    await _load();
  }

  Future<void> _delete(NameSuggestion s) async {
    if (!s.canDelete) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.funRemoveNameTitle,
      message: l10n.funRemoveNameBody(s.suggestedName),
      confirmLabel: l10n.actionRemove,
      variant: ConfirmDialogVariant.destructive,
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
                  ? l10n.funNoNameIdeasWereSaved
                  : l10n.funSuggestANameBelowEveryone,
            ),
            if (!_readOnly) _inputCard(),
          ],
        ),
      );
    }
    final boys =
        suggestions.where((s) => s.gender == BabyGender.male).toList();
    final girls =
        suggestions.where((s) => s.gender == BabyGender.female).toList();
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
              Expanded(child: _column(l10n.funBoys, boys)),
              const SizedBox(width: 12),
              Expanded(child: _column(l10n.funGirls, girls)),
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
                validator: (v) => validateFunNameSuggestion(AppLocalizations.of(context)!, v),
                autovalidateMode: autovalidate,
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: BabyGenderChipBar(
                      selected: _gender,
                      onSelected: (g) => setState(() => _gender = g),
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
              personDisplayName(AppLocalizations.of(context)!, suggestion.authorDisplayName),
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
                        ? l10n.funUnlike(suggestion.suggestedName)
                        : l10n.funLove(suggestion.suggestedName),
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
