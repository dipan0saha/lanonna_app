import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/vote_count_pill.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/fun_repository.dart';
import '../data/models/fun_models.dart';

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
    _visibleMonth = _dueDateMonth() ?? DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  DateTime? _parseDueDate() {
    final raw = widget.baby.expectedBirthDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? _dueDateMonth() {
    final due = _parseDueDate();
    if (due == null) return null;
    return DateTime(due.year, due.month);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payload = await context
          .read<FunRepository>()
          .fetchPredictions(widget.baby.id);
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _voteGender(String gender) async {
    await context.read<FunRepository>().setGenderVote(
      widget.baby.id,
      gender,
    );
    await _load();
  }

  Future<void> _lockPrediction() async {
    if (_payload?.viewerBirthdateVote != null) return;
    final date = _pendingGuess ?? _parseDueDate();
    if (date == null) {
      if (mounted) {
        AppSnackBar.showAlert(
          context,
          'Tap a date on the calendar to lock your guess',
        );
      }
      return;
    }
    await context.read<FunRepository>().setBirthdateVote(
      widget.baby.id,
      date,
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _pickDate() async {
    if (_payload?.viewerBirthdateVote != null) return;
    final due = _parseDueDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: due ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    final repo = context.read<FunRepository>();
    await repo.setBirthdateVote(widget.baby.id, picked);
    if (!mounted) return;
    await _load();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final p = _payload;
    final total = (p?.maleVotes ?? 0) + (p?.femaleVotes ?? 0);
    final boyPct = total > 0 ? ((p!.maleVotes / total) * 100).round() : 50;
    final birthdateLocked = p?.viewerBirthdateVote != null;
    final due = _parseDueDate();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Boy or Girl?', style: context.textStyles.labelLarge),
              const Spacer(),
              if (total > 0) VoteCountPill(total: total),
            ],
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Text('Birthdate guesses', style: context.textStyles.labelLarge),
          const SizedBox(height: 8),
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
                    viewerGuess: p?.viewerBirthdateVote,
                    pendingGuess: _pendingGuess,
                    onDayTap: p?.viewerBirthdateVote == null
                        ? (day) => setState(() => _pendingGuess = day)
                        : null,
                  ),
                  if (due != null &&
                      due.year == _visibleMonth.year &&
                      due.month == _visibleMonth.month)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Due date: ${_monthName(due.month)} ${due.day}',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text('Popular Dates', style: context.textStyles.labelLarge),
          if (p == null || p.birthdateHistogram.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No guesses yet - be the first!'),
            )
          else
            for (final row in p.birthdateHistogram)
              ListTile(
                title: Text(row.date),
                trailing: Text('${row.count} votes'),
              ),
          const SizedBox(height: 8),
          if (birthdateLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sageTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your guess is locked', style: context.textStyles.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    p!.viewerBirthdateVote!,
                    style: context.textStyles.bodyMedium,
                  ),
                ],
              ),
            )
          else ...[
            if (_pendingGuess != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Selected: ${_pendingGuess!.year}-${_pendingGuess!.month.toString().padLeft(2, '0')}-${_pendingGuess!.day.toString().padLeft(2, '0')}',
                  style: context.textStyles.bodySmall,
                ),
              ),
            FilledButton(
              key: const Key('lockPredictionBtn'),
              onPressed: _lockPrediction,
              child: const Text('Lock Prediction'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickDate,
              child: const Text('Pick date…'),
            ),
          ],
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
    this.onDayTap,
  });

  final DateTime month;
  final Map<String, int> voteCountsByDate;
  final DateTime? dueDate;
  final String? viewerGuess;
  final DateTime? pendingGuess;
  final void Function(DateTime day)? onDayTap;

  String _iso(int year, int month, int day) =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

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
      final iso = _iso(month.year, month.month, day);
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
