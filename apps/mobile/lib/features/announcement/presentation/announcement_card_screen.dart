import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import 'announcement_share.dart';
import 'widgets/announcement_keepsake_card.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../data/announcement_repository.dart';

class AnnouncementCardScreen extends StatefulWidget {
  const AnnouncementCardScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<AnnouncementCardScreen> createState() => _AnnouncementCardScreenState();
}

class _AnnouncementCardScreenState extends State<AnnouncementCardScreen> {
  AnnouncementDetail? _detail;
  final _comment = TextEditingController();
  var _loading = true;
  var _isOwner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    final detail =
        await context.read<AnnouncementRepository>().fetch(widget.babyId);
    setState(() {
      _detail = detail;
      _isOwner = baby?.role == 'owner' && baby?.id == widget.babyId;
      _loading = false;
    });
    if (detail == null && mounted) {
      context.replace('/baby/${widget.babyId}/announcement/create');
    }
  }

  Future<void> _squish() async {
    await context.read<AnnouncementRepository>().squish(widget.babyId);
    await _load();
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    await context.read<AnnouncementRepository>().addComment(widget.babyId, text);
    _comment.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = _detail;
    if (d == null) {
      return const Scaffold(body: Center(child: Text('No announcement yet')));
    }

    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
      title: 'Announcement',
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, size: 20),
          onPressed: () =>
              AnnouncementShare.shareBabyAnnouncement(context, widget.babyId),
        ),
        if (_isOwner)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () =>
                context.push('/baby/${widget.babyId}/announcement/create'),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                AnnouncementKeepsakeCard(detail: d),
                if (d.birthTime != null || d.weightText != null || d.lengthText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        if (d.birthTime != null)
                          _StatRow(icon: Icons.schedule_outlined, label: d.birthTime!),
                        if (d.weightText != null)
                          _StatRow(icon: Icons.monitor_weight_outlined, label: d.weightText!),
                        if (d.lengthText != null)
                          _StatRow(icon: Icons.straighten, label: d.lengthText!),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _squish,
                      icon: const Icon(Icons.favorite_border, size: 18),
                      label: Text('${d.squishCount} squishes'),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text('${d.commentCount} comments'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'COMMENTS',
                  style: context.textStyles.labelSmall?.copyWith(
                    color: context.brand.shellIconMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final c in d.comments)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['author_display_name'] as String? ?? 'Family',
                          style: context.textStyles.labelMedium,
                        ),
                        Text(c['body'] as String? ?? ''),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Material(
            elevation: 4,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendComment,
                      icon: const Icon(Icons.send),
                      color: context.colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: context.brand.shellIconMuted),
          const SizedBox(width: 8),
          Text(label, style: context.textStyles.bodyMedium),
        ],
      ),
    );
  }
}
