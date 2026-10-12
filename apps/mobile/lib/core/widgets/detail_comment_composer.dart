import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../comments/comment_composer_controller.dart';
import '../input/app_text_input_kind.dart';
import 'app_semantics.dart';
import 'app_text_field.dart';

/// Bottom comment field shared by event detail and photo detail.
class DetailCommentComposer extends StatelessWidget {
  const DetailCommentComposer({
    super.key,
    required this.controller,
    required this.semanticsId,
    this.sendSemanticsId,
  });

  final CommentComposerController controller;

  /// Semantics identifier for the text field (`event_comment`, `gallery_photo_comment`).
  final String semanticsId;

  /// Semantics identifier for the send button. Defaults to `{semanticsId}_send`.
  final String? sendSemanticsId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sendId = sendSemanticsId ?? '${semanticsId}_send';
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canSend = controller.canSend;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: AppSemantics.textField(
                    semanticsId,
                    AppTextField(
                      kind: AppTextInputKind.prose,
                      controller: controller.textController,
                      focusNode: controller.focusNode,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: l10n.commentComposerHint,
                      ),
                      onSubmitted: (_) => controller.submit(),
                    ),
                  ),
                ),
                AppSemantics.button(
                  sendId,
                  IconButton(
                    onPressed: canSend ? controller.submit : null,
                    tooltip: l10n.commentSend,
                    icon: const Icon(Icons.send),
                  ),
                  label: l10n.commentSend,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
