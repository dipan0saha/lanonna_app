import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/fun_repository.dart';
import '../data/models/fun_models.dart';

class NamesTab extends StatefulWidget {
  const NamesTab({super.key, required this.baby});

  final BabySummary baby;

  @override
  State<NamesTab> createState() => _NamesTabState();
}

class _NamesTabState extends State<NamesTab> {
  NamesPayload? _payload;
  final _input = TextEditingController();
  var _gender = 'male';
  var _loading = true;

  bool get _isOwner => widget.baby.role == 'owner';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payload =
          await context.read<FunRepository>().fetchNames(widget.baby.id);
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await context.read<FunRepository>().suggestName(
      widget.baby.id,
      text,
      _gender,
    );
    _input.clear();
    await _load();
  }

  Future<void> _like(NameSuggestion s) async {
    await context.read<FunRepository>().toggleLike(widget.baby.id, s.id);
    await _load();
  }

  Future<void> _delete(NameSuggestion s) async {
    await context.read<FunRepository>().deleteSuggestion(widget.baby.id, s.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final payload = _payload;
    final suggestions = payload?.suggestions ?? [];
    if (suggestions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.star_outline, size: 36, color: AppColors.primaryDark),
            const SizedBox(height: 12),
            Text(
              'No name suggestions yet',
              textAlign: TextAlign.center,
              style: context.textStyles.titleMedium,
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Suggest a name below — everyone gets a say.',
                textAlign: TextAlign.center,
              ),
            ),
            _inputCard(),
          ],
        ),
      );
    }
    final boys = suggestions.where((s) => s.gender == 'male').toList();
    final girls = suggestions.where((s) => s.gender == 'female').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _inputCard(),
          const SizedBox(height: 16),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _input,
              decoration: const InputDecoration(hintText: 'Suggest a name…'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'male', label: Text('Boy')),
                      ButtonSegment(value: 'female', label: Text('Girl')),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (s) => setState(() => _gender = s.first),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('Add')),
              ],
            ),
            if (!_isOwner)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'You can suggest 1 name per gender.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
          ],
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
                color: title == 'Boys' ? AppColors.primaryDark : AppColors.secondaryDark,
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
              isOwner: _isOwner,
              onLike: () => _like(s),
              onDelete: () => _delete(s),
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
    required this.isOwner,
    required this.onLike,
    required this.onDelete,
  });

  final NameSuggestion suggestion;
  final bool isOwner;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
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
                IconButton(
                  onPressed: onLike,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    suggestion.viewerHasLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 20,
                    color: suggestion.viewerHasLiked ? AppColors.primaryDark : null,
                  ),
                ),
                Text(
                  '${suggestion.likeCount}',
                  style: styles.labelMedium,
                ),
                if (isOwner)
                  IconButton(
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
