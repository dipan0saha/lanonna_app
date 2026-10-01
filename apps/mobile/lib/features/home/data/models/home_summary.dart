class HomeActivityItem {
  const HomeActivityItem({
    required this.id,
    required this.eventType,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String eventType;
  final String summary;
  final String createdAt;

  factory HomeActivityItem.fromJson(Map<String, dynamic> json) {
    return HomeActivityItem(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
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
      male: json['male'] as int? ?? 0,
      female: json['female'] as int? ?? 0,
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
      likeCount: json['like_count'] as int? ?? 0,
    );
  }
}

class NextUpEvent {
  const NextUpEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.location,
  });

  final String id;
  final String title;
  final String startsAt;
  final String? location;

  factory NextUpEvent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NextUpEvent(id: '', title: '', startsAt: '');
    }
    return NextUpEvent(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      startsAt: json['starts_at'] as String? ?? '',
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
      completedCount: json['completed_count'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      tasks: tasks
          .whereType<Map<String, dynamic>>()
          .map(GettingStartedTask.fromJson)
          .toList(),
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
  final List<HomeActivityItem> recentActivity;

  bool get showRichInsight =>
      voteCount > 0 || nameSuggestionCount > 0;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final insight = json['family_insight'] as Map<String, dynamic>? ?? {};
    final activity = json['recent_activity'] as List<dynamic>? ?? [];
    return HomeSummary(
      lifecycleStatus: json['lifecycle_status'] as String? ?? 'expecting',
      daysToDue: json['days_to_due'] as int?,
      nameSuggestionCount: insight['name_suggestion_count'] as int? ?? 0,
      voteCount: insight['vote_count'] as int? ?? 0,
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
      recentActivity: activity
          .whereType<Map<String, dynamic>>()
          .map(HomeActivityItem.fromJson)
          .toList(),
    );
  }
}
