import '../../../../core/json/json_readers.dart';
import '../../../../core/time/app_date_time.dart';

class HomeActivityItem {
  const HomeActivityItem({
    required this.id,
    required this.eventType,
    required this.summary,
    required this.createdAt,
    this.actorDisplayName,
    this.photoId,
  });

  final String id;
  final String eventType;
  final String summary;
  final String createdAt;
  final String? actorDisplayName;
  final String? photoId;

  factory HomeActivityItem.fromJson(Map<String, dynamic> json) {
    return HomeActivityItem(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      actorDisplayName: json['actor_display_name'] as String?,
      photoId: json['photo_id']?.toString(),
    );
  }
}

class GenderTotals {
  const GenderTotals({required this.male, required this.female});

  final int male;
  final int female;

  factory GenderTotals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GenderTotals(male: 0, female: 0);
    return GenderTotals(
      male: readInt(json['male']),
      female: readInt(json['female']),
    );
  }
}

class TopNameInsight {
  const TopNameInsight({required this.suggestedName, required this.likeCount});

  final String suggestedName;
  final int likeCount;

  factory TopNameInsight.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TopNameInsight(suggestedName: '', likeCount: 0);
    return TopNameInsight(
      suggestedName: json['suggested_name'] as String? ?? '',
      likeCount: readInt(json['like_count']),
    );
  }
}

class NextUpEvent {
  const NextUpEvent({
    required this.id,
    required this.title,
    this.startsAt,
    this.location,
  });

  final String id;
  final String title;
  final DateTime? startsAt;
  final String? location;

  factory NextUpEvent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NextUpEvent(id: '', title: '');
    }
    return NextUpEvent(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      startsAt: tryParseApiInstant(json['starts_at'] as String?),
      location: json['location'] as String?,
    );
  }
}

class GettingStartedTask {
  const GettingStartedTask({
    required this.id,
    required this.label,
    required this.done,
    this.deepLink,
  });

  final String id;
  final String label;
  final bool done;
  final String? deepLink;

  factory GettingStartedTask.fromJson(Map<String, dynamic> json) {
    return GettingStartedTask(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      deepLink: json['deep_link'] as String?,
    );
  }
}

class GettingStartedSummary {
  const GettingStartedSummary({
    required this.completedCount,
    required this.total,
    required this.tasks,
  });

  final int completedCount;
  final int total;
  final List<GettingStartedTask> tasks;

  factory GettingStartedSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GettingStartedSummary(completedCount: 0, total: 0, tasks: []);
    }
    final tasks = json['tasks'] as List<dynamic>? ?? [];
    return GettingStartedSummary(
      completedCount: readInt(json['completed_count']),
      total: readInt(json['total']),
      tasks: tasks
          .whereType<Map<String, dynamic>>()
          .map(GettingStartedTask.fromJson)
          .toList(),
    );
  }
}

class HomeTeaserPhoto {
  const HomeTeaserPhoto({required this.id, this.thumbUrl});

  final String id;
  final String? thumbUrl;

  factory HomeTeaserPhoto.fromJson(Map<String, dynamic> json) {
    return HomeTeaserPhoto(
      id: json['id']?.toString() ?? '',
      thumbUrl: json['thumb_url'] as String?,
    );
  }
}

class HomeTeasers {
  const HomeTeasers({
    required this.recentPhotos,
    required this.upcomingEvents,
  });

  final List<HomeTeaserPhoto> recentPhotos;
  final List<NextUpEvent> upcomingEvents;

  factory HomeTeasers.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HomeTeasers(recentPhotos: [], upcomingEvents: []);
    }
    return HomeTeasers(
      recentPhotos: (json['recent_photos'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HomeTeaserPhoto.fromJson)
          .toList(),
      upcomingEvents: (json['upcoming_events'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => NextUpEvent.fromJson(e))
          .toList(),
    );
  }
}

class BirthWelcomeSummary {
  const BirthWelcomeSummary({
    required this.babyName,
    required this.daysSinceBirth,
    this.welcomeVisibleUntil,
    this.photoDisplayUrl,
    this.announcementId,
  });

  final String babyName;
  final int daysSinceBirth;
  final String? welcomeVisibleUntil;
  final String? photoDisplayUrl;
  final String? announcementId;

  factory BirthWelcomeSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BirthWelcomeSummary(babyName: '', daysSinceBirth: 0);
    final ann = json['announcement'] as Map<String, dynamic>?;
    return BirthWelcomeSummary(
      babyName: json['baby_name'] as String? ?? '',
      daysSinceBirth: readInt(json['days_since_birth']),
      welcomeVisibleUntil: json['welcome_visible_until'] as String?,
      photoDisplayUrl: ann?['photo_display_url'] as String?,
      announcementId: ann?['announcement_id']?.toString(),
    );
  }
}

class SystemAnnouncementItem {
  const SystemAnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaDeepLink,
  });

  final String id;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaDeepLink;

  factory SystemAnnouncementItem.fromJson(Map<String, dynamic> json) {
    return SystemAnnouncementItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      ctaLabel: json['cta_label'] as String?,
      ctaDeepLink: json['cta_deep_link'] as String?,
    );
  }
}

class HomeNewFollower {
  const HomeNewFollower({
    required this.firebaseUid,
    required this.displayName,
    required this.joinedAt,
  });

  final String firebaseUid;
  final String displayName;
  final String joinedAt;

  factory HomeNewFollower.fromJson(Map<String, dynamic> json) {
    return HomeNewFollower(
      firebaseUid: json['firebase_uid'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      joinedAt: json['joined_at'] as String? ?? '',
    );
  }
}

class HomeInviteStatusRow {
  const HomeInviteStatusRow({
    required this.id,
    required this.inviteeEmail,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String inviteeEmail;
  final String status;
  final String createdAt;

  factory HomeInviteStatusRow.fromJson(Map<String, dynamic> json) {
    return HomeInviteStatusRow(
      id: json['id']?.toString() ?? '',
      inviteeEmail: json['invitee_email'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class HomeSummary {
  const HomeSummary({
    required this.lifecycleStatus,
    required this.nameSuggestionCount,
    required this.voteCount,
    required this.recentActivity,
    this.daysToDue,
    this.genderTotals,
    this.topName,
    this.topBirthdateGuess,
    this.nextUpEvent,
    this.gettingStarted,
    this.teasers,
    this.birthWelcome,
    this.systemAnnouncements = const [],
    this.newFollowers = const [],
    this.inviteStatus = const [],
  });

  final String lifecycleStatus;
  final int? daysToDue;
  final int nameSuggestionCount;
  final int voteCount;
  final GenderTotals? genderTotals;
  final TopNameInsight? topName;
  final String? topBirthdateGuess;
  final NextUpEvent? nextUpEvent;
  final GettingStartedSummary? gettingStarted;
  final HomeTeasers? teasers;
  final BirthWelcomeSummary? birthWelcome;
  final List<SystemAnnouncementItem> systemAnnouncements;
  final List<HomeNewFollower> newFollowers;
  final List<HomeInviteStatusRow> inviteStatus;
  final List<HomeActivityItem> recentActivity;

  bool get showRichInsight => voteCount > 0 || nameSuggestionCount > 0;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final insight = json['family_insight'] as Map<String, dynamic>? ?? {};
    final activity = json['recent_activity'] as List<dynamic>? ?? [];
    final announcements = json['system_announcements'] as List<dynamic>? ?? [];
    final followers = json['new_followers'] as List<dynamic>? ?? [];
    final invites = json['invite_status'] as List<dynamic>? ?? [];
    return HomeSummary(
      lifecycleStatus: json['lifecycle_status'] as String? ?? 'expecting',
      daysToDue: json['days_to_due'] == null
          ? null
          : readInt(json['days_to_due']),
      nameSuggestionCount: readInt(insight['name_suggestion_count']),
      voteCount: readInt(insight['vote_count']),
      genderTotals: GenderTotals.fromJson(
        insight['gender_totals'] as Map<String, dynamic>?,
      ),
      topName: insight['top_name'] != null
          ? TopNameInsight.fromJson(insight['top_name'] as Map<String, dynamic>)
          : null,
      topBirthdateGuess: insight['top_birthdate_guess'] as String?,
      nextUpEvent: NextUpEvent.fromJson(
        json['next_up_event'] as Map<String, dynamic>?,
      ),
      gettingStarted: GettingStartedSummary.fromJson(
        json['getting_started'] as Map<String, dynamic>?,
      ),
      teasers: HomeTeasers.fromJson(json['teasers'] as Map<String, dynamic>?),
      birthWelcome: json['birth_welcome'] != null
          ? BirthWelcomeSummary.fromJson(
              json['birth_welcome'] as Map<String, dynamic>,
            )
          : null,
      systemAnnouncements: announcements
          .whereType<Map<String, dynamic>>()
          .map(SystemAnnouncementItem.fromJson)
          .toList(),
      newFollowers: followers
          .whereType<Map<String, dynamic>>()
          .map(HomeNewFollower.fromJson)
          .toList(),
      inviteStatus: invites
          .whereType<Map<String, dynamic>>()
          .map(HomeInviteStatusRow.fromJson)
          .toList(),
      recentActivity: activity
          .whereType<Map<String, dynamic>>()
          .map(HomeActivityItem.fromJson)
          .toList(),
    );
  }
}
