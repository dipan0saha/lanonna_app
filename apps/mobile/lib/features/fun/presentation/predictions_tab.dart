import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/person_display_label.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_modal_sheet.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/vote_count_pill.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/fun_repository.dart';
import '../data/models/fun_models.dart';
import '../domain/birthdate_prediction.dart';
import '../domain/gender_vote_display.dart';
import '../../../core/theme/app_button_styles.dart';

class PredictionsTab extends StatefulWidget {
  const PredictionsTab({super.key, required this.baby});

  final BabySummary baby;

  @override
  State<PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<PredictionsTab> {
  PredictionsPayload? _payload;
  var _loading = true;
  String? _error;
  late DateTime _visibleMonth;
  DateTime? _pendingGuess;

  @override
  void initState() {
    super.initState();
    final due = babyExpectedDueDate(widget.baby);
    _visibleMonth = visibleMonthForBirthdateGuess(dueDate: due);
    _load();
  }

  @override
  void didUpdateWidget(covariant PredictionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Baby switch reuses this State: reset per-baby state and reload.
    if (oldWidget.baby.id != widget.baby.id) {
      _payload = null;
      _pendingGuess = null;
      _visibleMonth = visibleMonthForBirthdateGuess(
        dueDate: babyExpectedDueDate(widget.baby),
      );
      _load();
    }
  }

  /// The spinner shows only while nothing is on screen; reloads after a vote
  /// or pull-to-refresh keep the tab and its scroll position, and a failed
  /// reload is a snackbar.
  Future<void> _load() async {
    if (_payload == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final babyId = widget.baby.id;
    try {
      final payload = await context.read<FunRepository>().fetchPredictions(
        babyId,
      );
      // Ignore a response for a baby that is no longer shown.
      if (!mounted || babyId != widget.baby.id) return;
      final due = babyExpectedDueDate(widget.baby);
      setState(() {
        _payload = payload;
        _loading = false;
        _visibleMonth = visibleMonthForBirthdateGuess(
          savedVoteIso: payload.viewerBirthdateVote,
          dueDate: due,
        );
        _pendingGuess = null;
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

  bool get _predictionsClosed =>
      widget.baby.predictionsClosed || (_payload?.predictionsClosed ?? false);

  Future<void> _voteGender(BabyGender gender) async {
    final before = _payload;
    if (_predictionsClosed || before == null) return;
    final optimistic = before.withGenderVote(gender);
    final ok = await runOptimisticMutation(
      context,
      apply: () => setState(() => _payload = optimistic),
      revert: () {
        if (mounted && identical(_payload, optimistic)) {
          setState(() => _payload = before);
        }
      },
      action: () =>
          context.read<FunRepository>().setGenderVote(widget.baby.id, gender),
    );
    if (!ok || !mounted) return;
    await _load();
  }

  Future<void> _submitBirthdateGuess() async {
    if (_predictionsClosed) return;
    final l10n = AppLocalizations.of(context)!;
    final saved = _payload?.viewerBirthdateVote;
    final date = birthdateGuessToSubmit(pendingSelection: _pendingGuess);
    if (date == null) return;
    final locale = localeNameForFormatting(context);
    final dateLabel = formatApiCalendarDateFromParts(date, locale);
    final isUpdate = saved != null && saved.isNotEmpty;
    final ok = await showConfirmDialog(
      context,
      title: isUpdate
          ? l10n.funBirthdateConfirmUpdateTitle
          : l10n.funBirthdateConfirmSaveTitle,
      message: isUpdate
          ? l10n.funBirthdateConfirmUpdateBody(dateLabel)
          : l10n.funBirthdateConfirmSaveBody(dateLabel),
      confirmLabel: l10n.funBirthdateConfirmAction,
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FunRepository>().setBirthdateVote(
        widget.baby.id,
        date,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
    }
  }

  Future<void> _pickDate() async {
    if (_predictionsClosed) return;
    final due = babyExpectedDueDate(widget.baby);
    final payload = _payload;
    final first = birthdatePickerFirstDate(
      voteMinIso: payload?.birthdateVoteMin,
      dueDate: due,
    );
    final last = birthdatePickerLastDate(
      voteMaxIso: payload?.birthdateVoteMax,
      dueDate: due,
    );
    if (first.isAfter(last)) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: birthdatePickerInitialDate(
        pendingSelection: _pendingGuess,
        savedVoteIso: payload?.viewerBirthdateVote,
        dueDate: due,
      ),
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() => _pendingGuess = picked);
  }

  void _showVoters() {
    final voters = _payload?.genderVoters ?? [];
    final l10n = AppLocalizations.of(context)!;
    showAppModalSheet(
      context: context,
      title: l10n.labelVoted,
      subtitle: voters.isEmpty
          ? AppLocalizations.of(context)!.funNoVotesYet
          : l10n.predictionVoteCount(voters.length),
      bodyBuilder: (context) => AppModalSheetListBody(
        children: [
          for (final v in voters)
            ListTile(
              title: Text(personDisplayName(AppLocalizations.of(context)!, v.displayName)),
              subtitle: Text(
                v.gender.label(AppLocalizations.of(context)!),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, int> _voteCountByDate() {
    final map = <String, int>{};
    for (final row in _payload?.birthdateHistogram ?? const []) {
      map[row.date] = row.count;
    }
    return map;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _selectCalendarDay(DateTime day) {
    if (_predictionsClosed) return;
    setState(() => _pendingGuess = day);
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
    final l10n = AppLocalizations.of(context)!;
    final locale = localeNameForFormatting(context);
    final p = _payload;
    final genderVotes = genderVoteDisplay(
      maleVotes: p?.maleVotes ?? 0,
      femaleVotes: p?.femaleVotes ?? 0,
    );
    final total = genderVotes.total;
    final savedBirthdate = p?.viewerBirthdateVote;
    final due = babyExpectedDueDate(widget.baby);
    final closed = _predictionsClosed;
    final submitEnabled =
        !closed &&
        birthdateGuessSubmitEnabled(
          pendingSelection: _pendingGuess,
          savedVoteIso: savedBirthdate,
        );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          AppSpacing.lg,
          AppMetrics.horizontalPadding,
          AppSpacing.lg,
        ),
        children: [
          if (closed)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.predictionsClosedNote,
                style: context.textStyles.bodyMedium,
              ),
            ),
          AppSectionTitle(
            title: l10n.labelBoyGirl2,
            action: total > 0 ? VoteCountPill(total: total) : null,
          ),
          Row(
            children: [
              Expanded(
                child: _genderBox(
                  BabyGender.male.label(l10n),
                  p?.viewerGenderVote == BabyGender.male,
                  closed ? null : () => _voteGender(BabyGender.male),
                  genderVotes.displayPercentForMale(),
                  p?.maleVotes ?? 0,
                  semanticsId: 'fun_vote_boy',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _genderBox(
                  BabyGender.female.label(l10n),
                  p?.viewerGenderVote == BabyGender.female,
                  closed ? null : () => _voteGender(BabyGender.female),
                  genderVotes.displayPercentForFemale(),
                  p?.femaleVotes ?? 0,
                  semanticsId: 'fun_vote_girl',
                ),
              ),
            ],
          ),
          if (genderVotes.maleProgress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(
                AppMetrics.predictionBarRadius,
              ),
              child: LinearProgressIndicator(
                value: genderVotes.maleProgress,
                minHeight: AppMetrics.predictionBarHeight,
                backgroundColor: AppColors.peachTint,
                color: AppColors.primaryDark,
              ),
            ),
          ],
          if (p?.viewerGenderVote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(context)!.predictionYourGenderVote(
                  p!.viewerGenderVote!.label(AppLocalizations.of(context)!),
                ),
                style: context.textStyles.bodySmall,
              ),
            ),
          TextButton(
            onPressed: _showVoters,
            child: Text(AppLocalizations.of(context)!.funViewWhoVoted),
          ),
          const SizedBox(height: AppMetrics.sectionBlockSpacing),
          AppSectionTitle(title: l10n.labelPopularDates),
          if (p == null || p.birthdateHistogram.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                closed ? AppLocalizations.of(context)!.funNoGuessesYet : AppLocalizations.of(context)!.funNoGuessesYetBeThe,
              ),
            )
          else
            _PopularDatesList(histogram: p.birthdateHistogram, locale: locale),
          const SizedBox(height: AppMetrics.sectionBlockSpacing),
          AppSectionTitle(title: l10n.labelBirthdateGuesses),
          Card(
            child: Padding(
              padding: AppMetrics.monthGridCardPadding,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppIconButton(
                        semanticsId: 'predictions_previous_month',
                        label: l10n.actionPreviousMonth,
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        formatMonthYear(
                          _visibleMonth,
                          localeNameForFormatting(context),
                        ),
                        style: context.calendarMonthTitleStyle,
                      ),
                      AppIconButton(
                        semanticsId: 'predictions_next_month',
                        label: l10n.actionNextMonth,
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  _PredictionsMonthGrid(
                    month: _visibleMonth,
                    voteCountsByDate: _voteCountByDate(),
                    dueDate: due,
                    viewerGuess: savedBirthdate,
                    pendingGuess: closed ? null : _pendingGuess,
                    onDayTap: closed ? null : _selectCalendarDay,
                  ),
                  if (due != null &&
                      due.year == _visibleMonth.year &&
                      due.month == _visibleMonth.month)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.funBirthdateDueDate(
                          formatMonthDay(due, localeNameForFormatting(context)),
                        ),
                        style: context.textStyles.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (savedBirthdate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.funBirthdateYourGuess(
                  formatApiCalendarDate(savedBirthdate, locale),
                ),
                style: context.textStyles.bodySmall,
              ),
            ),
          if (!closed && _pendingGuess != null && submitEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.funBirthdateSelected(
                  formatApiCalendarDateFromParts(_pendingGuess!, locale),
                ),
                style: context.textStyles.bodySmall,
              ),
            ),
          if (!closed) ...[
            FilledButton(
              key: const Key('lockPredictionBtn'),
              onPressed: submitEnabled ? _submitBirthdateGuess : _pickDate,
              child: Text(
                savedBirthdate == null
                    ? l10n.funBirthdateSaveGuess
                    : l10n.funBirthdateUpdateGuess,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: AppButtonStyles.outlinedAccent,
              onPressed: _pickDate,
              child: Text(l10n.funBirthdatePickDate),
            ),
          ],
        ],
      ),
    );
  }

  Widget _genderBox(
    String label,
    bool selected,
    VoidCallback? onTap,
    int pct,
    int count, {
    String? semanticsId,
  }) {
    final child = InkWell(
      onTap: onTap,
      child: Container(
        padding: AppMetrics.borderedListRowPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppMetrics.fieldRadius),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 2 : 1,
          ),
          color: AppColors.surface,
        ),
        child: Column(
          children: [
            Text(label, style: context.textStyles.titleSmall),
            Text(
              AppLocalizations.of(
                context,
              )!.predictionGenderVoteShare(pct, count),
            ),
          ],
        ),
      ),
    );
    if (semanticsId != null && onTap != null) {
      return AppSemantics.button(semanticsId, child, label: label);
    }
    return child;
  }
}

class _PopularDatesList extends StatelessWidget {
  const _PopularDatesList({required this.histogram, required this.locale});

  final List<BirthdateVoteCount> histogram;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final maxCount = histogram.fold<int>(
      0,
      (max, row) => row.count > max ? row.count : max,
    );
    return Column(
      children: [
        for (final row in histogram)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.smMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatApiCalendarDate(row.date, locale),
                        style: context.textStyles.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${row.count}',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xxs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppMetrics.predictionBarRadius,
                  ),
                  child: LinearProgressIndicator(
                    value: maxCount > 0 ? row.count / maxCount : 0,
                    minHeight: AppMetrics.predictionBarHeight,
                    backgroundColor: AppColors.border,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PredictionsMonthGrid extends StatelessWidget {
  const _PredictionsMonthGrid({
    required this.month,
    required this.voteCountsByDate,
    this.dueDate,
    this.viewerGuess,
    this.pendingGuess,
    this.onDayTap,
  });

  final DateTime month;
  final Map<String, int> voteCountsByDate;
  final DateTime? dueDate;
  final String? viewerGuess;
  final DateTime? pendingGuess;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[
      for (final label in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(child: Text(label, style: context.textStyles.labelSmall)),
    ];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final iso = birthdateGuessIso(DateTime(month.year, month.month, day));
      final count = voteCountsByDate[iso] ?? 0;
      final isDue =
          dueDate != null &&
          dueDate!.year == month.year &&
          dueDate!.month == month.month &&
          dueDate!.day == day;
      final isMine = viewerGuess == iso;
      final isPending =
          pendingGuess != null &&
          pendingGuess!.year == month.year &&
          pendingGuess!.month == month.month &&
          pendingGuess!.day == day;
      cells.add(
        GestureDetector(
          onTap: onDayTap == null
              ? null
              : () => onDayTap!(DateTime(month.year, month.month, day)),
          child: Container(
            decoration: BoxDecoration(
              color: isDue
                  ? AppColors.peachTint
                  : isMine || isPending
                  ? AppColors.sageTint
                  : null,
              borderRadius: BorderRadius.circular(6),
              border: isDue || isPending
                  ? Border.all(color: AppColors.primaryDark)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: context.textStyles.labelSmall?.copyWith(
                    fontWeight: isDue ? FontWeight.bold : null,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
