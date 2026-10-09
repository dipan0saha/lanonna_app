import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_section_title.dart';
import '../../../core/widgets/vote_count_pill.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/fun_repository.dart';
import '../data/models/fun_models.dart';
import '../domain/birthdate_prediction.dart';

class PredictionsTab extends StatefulWidget {
  const PredictionsTab({super.key, required this.baby});

  final BabySummary baby;

  @override
  State<PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<PredictionsTab> {
  PredictionsPayload? _payload;
  var _loading = true;
  late DateTime _visibleMonth;
  DateTime? _pendingGuess;

  @override
  void initState() {
    super.initState();
    final due = babyExpectedDueDate(widget.baby);
    _visibleMonth = visibleMonthForBirthdateGuess(dueDate: due);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payload = await context
          .read<FunRepository>()
          .fetchPredictions(widget.baby.id);
      if (!mounted) return;
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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _voteGender(String gender) async {
    try {
      await context.read<FunRepository>().setGenderVote(
        widget.baby.id,
        gender,
      );
      await _load();
    } catch (e) {
      if (mounted) AppSnackBar.showAlert(context, apiErrorMessage(e));
    }
  }

  Future<void> _submitBirthdateGuess() async {
    final l10n = AppLocalizations.of(context)!;
    final saved = _payload?.viewerBirthdateVote;
    final date = birthdateGuessToSubmit(pendingSelection: _pendingGuess);
    if (date == null) return;
    final iso = birthdateGuessIso(date);
    final isUpdate = saved != null && saved.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isUpdate
              ? l10n.funBirthdateConfirmUpdateTitle
              : l10n.funBirthdateConfirmSaveTitle,
        ),
        content: Text(
          isUpdate
              ? l10n.funBirthdateConfirmUpdateBody(iso)
              : l10n.funBirthdateConfirmSaveBody(iso),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.funBirthdateConfirmAction),
          ),
        ],
      ),
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
      if (mounted) AppSnackBar.showAlert(context, apiErrorMessage(e));
    }
  }

  Future<void> _pickDate() async {
    final due = babyExpectedDueDate(widget.baby);
    final picked = await showDatePicker(
      context: context,
      initialDate: birthdatePickerInitialDate(
        pendingSelection: _pendingGuess,
        savedVoteIso: _payload?.viewerBirthdateVote,
        dueDate: due,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() => _pendingGuess = picked);
  }

  void _showVoters() {
    final voters = _payload?.genderVoters ?? [];
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Who voted', style: context.textStyles.titleMedium),
          for (final v in voters)
            ListTile(
              title: Text(v.displayName),
              subtitle: Text(v.gender == 'male' ? 'Boy' : 'Girl'),
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
    setState(() => _pendingGuess = day);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = AppLocalizations.of(context)!;
    final p = _payload;
    final total = (p?.maleVotes ?? 0) + (p?.femaleVotes ?? 0);
    final boyPct = total > 0 ? ((p!.maleVotes / total) * 100).round() : 50;
    final savedBirthdate = p?.viewerBirthdateVote;
    final due = babyExpectedDueDate(widget.baby);
    final submitEnabled = birthdateGuessSubmitEnabled(
      pendingSelection: _pendingGuess,
      savedVoteIso: savedBirthdate,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionTitle(
            title: 'Boy or Girl?',
            action: total > 0 ? VoteCountPill(total: total) : null,
          ),
          Row(
            children: [
              Expanded(
                child: _genderBox(
                  'Boy',
                  p?.viewerGenderVote == 'male',
                  () => _voteGender('male'),
                  boyPct,
                  p?.maleVotes ?? 0,
                  semanticsId: 'fun_vote_boy',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _genderBox(
                  'Girl',
                  p?.viewerGenderVote == 'female',
                  () => _voteGender('female'),
                  100 - boyPct,
                  p?.femaleVotes ?? 0,
                  semanticsId: 'fun_vote_girl',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? p!.maleVotes / total : 0.5,
              minHeight: 8,
              backgroundColor: AppColors.peachTint,
              color: AppColors.primaryDark,
            ),
          ),
          if (p?.viewerGenderVote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Your vote: ${p!.viewerGenderVote == 'male' ? 'Boy' : 'Girl'}',
                style: context.textStyles.bodySmall,
              ),
            ),
          TextButton(onPressed: _showVoters, child: const Text('View who voted')),
          const SizedBox(height: AppMetrics.sectionBlockSpacing),
          const AppSectionTitle(title: 'Birthdate guesses'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                        style: context.textStyles.titleMedium,
                      ),
                      IconButton(
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
                    pendingGuess: _pendingGuess,
                    onDayTap: _selectCalendarDay,
                  ),
                  if (due != null &&
                      due.year == _visibleMonth.year &&
                      due.month == _visibleMonth.month)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.funBirthdateDueDate(
                          '${_monthName(due.month)} ${due.day}',
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
          const SizedBox(height: AppMetrics.sectionBlockSpacing),
          const AppSectionTitle(title: 'Popular Dates'),
          if (p == null || p.birthdateHistogram.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No guesses yet - be the first!'),
            )
          else
            for (final row in p.birthdateHistogram)
              ListTile(
                title: Text(row.date),
                trailing: Text(l10n.predictionVoteCount(row.count)),
              ),
          const SizedBox(height: 8),
          if (savedBirthdate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.funBirthdateYourGuess(savedBirthdate),
                style: context.textStyles.bodySmall,
              ),
            ),
          if (_pendingGuess != null && submitEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.funBirthdateSelected(birthdateGuessIso(_pendingGuess!)),
                style: context.textStyles.bodySmall,
              ),
            ),
          FilledButton(
            key: const Key('lockPredictionBtn'),
            onPressed: submitEnabled ? _submitBirthdateGuess : null,
            child: Text(
              savedBirthdate == null
                  ? l10n.funBirthdateSaveGuess
                  : l10n.funBirthdateUpdateGuess,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pickDate,
            child: Text(l10n.funBirthdatePickDate),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m - 1];
  }

  Widget _genderBox(
    String label,
    bool selected,
    VoidCallback onTap,
    int pct,
    int count, {
    String? semanticsId,
  }) {
    final child = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 2 : 1,
          ),
          color: selected ? AppColors.sageTint : AppColors.surface,
        ),
        child: Column(
          children: [
            Text(label, style: context.textStyles.titleSmall),
            Text('$pct% ($count)'),
          ],
        ),
      ),
    );
    if (semanticsId != null) {
      return AppSemantics.button(semanticsId, child, label: label);
    }
    return child;
  }
}

class _PredictionsMonthGrid extends StatelessWidget {
  const _PredictionsMonthGrid({
    required this.month,
    required this.voteCountsByDate,
    this.dueDate,
    this.viewerGuess,
    this.pendingGuess,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<String, int> voteCountsByDate;
  final DateTime? dueDate;
  final String? viewerGuess;
  final DateTime? pendingGuess;
  final void Function(DateTime day) onDayTap;

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
      final isDue = dueDate != null &&
          dueDate!.year == month.year &&
          dueDate!.month == month.month &&
          dueDate!.day == day;
      final isMine = viewerGuess == iso;
      final isPending = pendingGuess != null &&
          pendingGuess!.year == month.year &&
          pendingGuess!.month == month.month &&
          pendingGuess!.day == day;
      cells.add(
        GestureDetector(
          onTap: () => onDayTap(DateTime(month.year, month.month, day)),
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
