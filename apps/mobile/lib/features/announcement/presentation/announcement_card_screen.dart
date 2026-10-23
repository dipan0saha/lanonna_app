import 'package:flutter/material.dart';

import '../../../core/widgets/app_empty_state.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/domain/person_display_label.dart';
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
import '../../../l10n/app_localizations.dart';
import '../../../core/data/parallel_requests.dart';

class AnnouncementCardScreen extends StatefulWidget {
  const AnnouncementCardScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<AnnouncementCardScreen> createState() => _AnnouncementCardScreenState();
}

class _AnnouncementCardScreenState extends State<AnnouncementCardScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
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

  /// The full-screen spinner shows only until the card first loads; later
  /// reloads (squish, comment, edit) keep it on screen.
  Future<void> _load() async {
    if (_detail == null) setState(() => _loading = true);
    try {
      final (routeBaby, detail) = await waitBoth(
        context.read<HomeRepository>().babyById(widget.babyId),
        context.read<AnnouncementRepository>().fetch(widget.babyId),
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isOwner = routeBaby?.role == 'owner';
        _loading = false;
      });
      if (detail == null && _isOwner && mounted) {
        context.replace('/baby/${widget.babyId}/announcement/create');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
    }
  }

  Future<void> _squish() async {
    try {
      await context.read<AnnouncementRepository>().squish(widget.babyId);
      await _load();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
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
        AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = _detail;
    if (d == null) {
      return Scaffold(
        body: AppEmptyState(
          icon: Icons.celebration_outlined,
          title: l10n.emptyAnnouncementYet,
        ),
      );
    }
    return PrototypeSubpageScaffold(
      title: l10n.announcementTitle,
      actions: [
        AppIconButton(
          semanticsId: 'announcement_share',
          label: l10n.actionShareAnnouncement,
          icon: const Icon(Icons.share_outlined, size: 20),
          onPressed: () =>
              AnnouncementShare.shareBabyAnnouncement(context, widget.babyId),
        ),
        if (_isOwner)
          AppIconButton(
            semanticsId: 'announcement_edit',
            label: l10n.actionEditAnnouncement,
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
                  l10n.announcementCommentsHeading,
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
                          personDisplayName(
                            l10n,
                            c['author_display_name'] as String?,
                          ),
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
                        decoration: InputDecoration(
                          hintText: l10n.commentComposerHint,
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    AppIconButton(
                      semanticsId: 'announcement_comment_send',
                      label: l10n.commentSend,
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
