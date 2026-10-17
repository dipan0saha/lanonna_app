import 'package:flutter/material.dart';

import '../../l10n/placeholder_rich_text.dart';
import '../../theme/app_colors.dart';
import '../../theme/la_nonna_theme.dart';

/// A localized feed / inbox sentence whose people are styled placeholders.
///
/// Built by `activitySentence` and `inboxSentence` from the row's structured
/// type + params; [message] is a gen-l10n call that receives one token per
/// entry in [people] (see [PlaceholderRichText]).
class FeedSentence {
  const FeedSentence(this.message, [this.people = const []]);

  /// Copy the server stored for a row this build cannot render (unknown type,
  /// or a legacy row missing a required value).
  factory FeedSentence.stored(String text) => FeedSentence((_) => text);

  final String Function(List<String> tokens) message;
  final List<String> people;

  List<MessagePlaceholder> get _spans => [
        for (final name in people) MessagePlaceholder(label: name),
      ];

  /// The sentence with names filled in (semantics labels).
  String get plainText => PlaceholderRichText.plainText(message, _spans);
}

/// Renders a [FeedSentence] with the people in bold.
class FeedSentenceText extends StatelessWidget {
  const FeedSentenceText({super.key, required this.sentence});

  final FeedSentence sentence;

  @override
  Widget build(BuildContext context) {
    final base = context.textStyles.bodySmall?.copyWith(
      height: 1.4,
      color: AppColors.textPrimary,
    );
    return PlaceholderRichText(
      message: sentence.message,
      placeholders: sentence._spans,
      style: base,
      placeholderStyle: base?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
