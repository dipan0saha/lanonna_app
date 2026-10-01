class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.videoCallUrl,
    this.coverPhotoId,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? videoCallUrl;
  final String? coverPhotoId;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      location: json['location'] as String?,
      videoCallUrl: json['video_call_url'] as String?,
      coverPhotoId: json['cover_photo_id'] as String?,
    );
  }
}

class RsvpSummary {
  RsvpSummary({
    required this.going,
    required this.maybe,
    required this.cantGo,
  });

  final int going;
  final int maybe;
  final int cantGo;

  factory RsvpSummary.fromJson(Map<String, dynamic> json) {
    return RsvpSummary(
      going: json['going'] as int? ?? 0,
      maybe: json['maybe'] as int? ?? 0,
      cantGo: json['cant_go'] as int? ?? 0,
    );
  }
}

class EventComment {
  EventComment({
    required this.id,
    required this.body,
    required this.authorDisplayName,
    required this.isMine,
  });

  final String id;
  final String body;
  final String authorDisplayName;
  final bool isMine;

  factory EventComment.fromJson(Map<String, dynamic> json) {
    return EventComment(
      id: json['id'] as String,
      body: json['body'] as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Family member',
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}

class EventDetail extends CalendarEvent {
  EventDetail({
    required super.id,
    required super.title,
    super.description,
    required super.startsAt,
    super.endsAt,
    super.location,
    super.videoCallUrl,
    super.coverPhotoId,
    required this.rsvpSummary,
    this.viewerRsvp,
    required this.comments,
  });

  final RsvpSummary rsvpSummary;
  final String? viewerRsvp;
  final List<EventComment> comments;

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    final commentsRaw = json['comments'];
    return EventDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      location: json['location'] as String?,
      videoCallUrl: json['video_call_url'] as String?,
      coverPhotoId: json['cover_photo_id'] as String?,
      rsvpSummary: RsvpSummary.fromJson(
        json['rsvp_summary'] as Map<String, dynamic>? ?? {},
      ),
      viewerRsvp: json['viewer_rsvp'] as String?,
      comments: commentsRaw is List
          ? commentsRaw
              .whereType<Map<String, dynamic>>()
              .map(EventComment.fromJson)
              .toList()
          : [],
    );
  }
}
