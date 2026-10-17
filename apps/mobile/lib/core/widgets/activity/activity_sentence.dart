import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';

import '../../../features/home/data/models/home_summary.dart';
import '../../domain/activity_event_type.dart';
import '../../domain/feed_params.dart';
import '../../domain/person_display_label.dart';
import 'feed_sentence.dart';

/// The ARB sentence for one activity row.
///
/// Names the API returned as null use the shared fallbacks
/// (`personDisplayName`, `babyNameLabel`). A row whose type this build does
/// not know, or a legacy row missing a value its sentence needs (its source
/// was deleted before migration 038 backfilled params), shows the stored
/// English summary.
FeedSentence activitySentence(AppLocalizations l10n, HomeActivityItem item) {
  final params = item.params;
  final actor = personDisplayName(l10n, item.actorDisplayName);
  final caption = params.text(FeedParam.caption);
  final itemName = params.text(FeedParam.itemName);
  final title = params.text(FeedParam.eventTitle);
  final name = params.text(FeedParam.suggestedName);
  final stored = FeedSentence.stored(item.summary);

  FeedSentence byActor(String Function(String actor) message) =>
      FeedSentence((t) => message(t[0]), [actor]);

  return switch (item.eventType) {
    ActivityEventType.photoShared => byActor(
        (a) => caption == null
            ? l10n.activityPhotoShared(a)
            : l10n.activityPhotoSharedCaption(a, caption),
      ),
    ActivityEventType.photoSquish => byActor(
        (a) => caption == null
            ? l10n.activityPhotoSquish(a)
            : l10n.activityPhotoSquishCaption(a, caption),
      ),
    ActivityEventType.photoComment => byActor(
        (a) => caption == null
            ? l10n.activityPhotoComment(a)
            : l10n.activityPhotoCommentCaption(a, caption),
      ),
    ActivityEventType.registryItemAdded when itemName != null =>
      byActor((a) => l10n.activityRegistryItemAdded(a, itemName)),
    ActivityEventType.registryPurchased when itemName != null =>
      byActor((a) => l10n.activityRegistryPurchased(a, itemName)),
    ActivityEventType.registryClaimed when itemName != null =>
      FeedSentence((_) => l10n.activityRegistryClaimed(itemName)),
    ActivityEventType.eventCreated when title != null =>
      byActor((a) => l10n.activityEventCreated(a, title)),
    ActivityEventType.nameSuggested when name != null =>
      byActor((a) => l10n.activityNameSuggested(a, name)),
    ActivityEventType.genderVoteCast => byActor(
        (a) => l10n.activityGenderVoteCast(
          a,
          BabyGender.fromApi(params.text(FeedParam.gender)).apiValue,
        ),
      ),
    ActivityEventType.babyArrived => FeedSentence(
        (_) => l10n.activityBabyArrived(
          babyNameLabel(l10n, params.text(FeedParam.babyName)),
        ),
      ),
    ActivityEventType.memberRemoved => item.targetDisplayName?.trim().isNotEmpty ==
            true
        ? FeedSentence(
            (t) => l10n.activityMemberRemoved(t[0], t[1]),
            [actor, item.targetDisplayName!.trim()],
          )
        : byActor(l10n.activityMemberRemovedUnnamed),
    ActivityEventType.memberLeft => byActor(l10n.activityMemberLeft),
    _ => stored,
  };
}
