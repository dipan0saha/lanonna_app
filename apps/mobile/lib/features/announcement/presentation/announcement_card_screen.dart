import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import 'announcement_share.dart';
import 'widgets/announcement_keepsake_card.dart';
import '../../home/data/home_repository.dart';
import '../data/announcement_repository.dart';
import '../domain/announcement_navigation.dart';

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
    try {
      final homeRepo = context.read<HomeRepository>();
      final routeBaby = await homeRepo.babyById(widget.babyId);
      if (!mounted) return;
      final detail = await context.read<AnnouncementRepository>().fetch(
        widget.babyId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isOwner = routeBaby?.role == 'owner';
        _loading = false;
      });
      if (detail == null && mounted) {
        context.replace('/baby/${widget.babyId}/announcement/create');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.showAlert(context, apiErrorMessage(e));
    }
  }

  Future<void> _squish() async {
    try {
      await context.read<AnnouncementRepository>().squish(widget.babyId);
      await _load();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    }
  }

  Future<void> _sendComment() async {
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _comment.text,
    );
    if (text.isEmpty) return;
    try {
      await context.read<AnnouncementRepository>().addComment(
        widget.babyId,
        text,
      );
      _comment.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    }
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
      title: 'Announcement',
      actions: [
        AppIconButton(
          semanticsId: 'announcement_share',
          label: 'Share announcement',
          icon: const Icon(Icons.share_outlined, size: 20),
          onPressed: () =>
              AnnouncementShare.shareBabyAnnouncement(context, widget.babyId),
        ),
        if (_isOwner)
          AppIconButton(
            semanticsId: 'announcement_edit',
            label: 'Edit announcement',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              final saved = await context.push<bool>(
                announcementCreateLocation(widget.babyId),
              );
              if (saved == true && mounted) await _load();
            },
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.horizontalPadding,
                8,
                AppMetrics.horizontalPadding,
                16,
              ),
              children: [
                Center(
                  child: AnnouncementKeepsakeCard(
                    detail: d,
                    onSignedUrlError: _load,
                    showEngagementRow: true,
                    squishCount: d.squishCount,
                    commentCount: d.commentCount,
                    onSquishTap: _squish,
                  ),
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
                      child: AppTextField(
                        kind: AppTextInputKind.prose,
                        controller: _comment,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    AppIconButton(
                      semanticsId: 'announcement_comment_send',
                      label: 'Send comment',
                      onPressed: _sendComment,
                      color: context.colors.primary,
                      icon: const Icon(Icons.send),
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
