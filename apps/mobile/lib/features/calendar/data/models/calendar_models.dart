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
    this.catalogSuggestionId,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? videoCallUrl;
  final String? coverPhotoId;
  final String? catalogSuggestionId;

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
      catalogSuggestionId: json['catalog_suggestion_id'] as String?,
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

class RsvpAttendee {
  RsvpAttendee({
    required this.firebaseUid,
    required this.status,
    required this.displayName,
  });

  final String firebaseUid;
  final String status;
  final String displayName;

  factory RsvpAttendee.fromJson(Map<String, dynamic> json) {
    return RsvpAttendee(
      firebaseUid: json['firebase_uid'] as String? ?? '',
      status: json['status'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Family member',
    );
  }
}

class EventComment {
  EventComment({
    required this.id,
    required this.body,
    required this.authorDisplayName,
    required this.isMine,
    required this.canEdit,
    required this.canDelete,
  });

  final String id;
  final String body;
  final String authorDisplayName;
  final bool isMine;
  final bool canEdit;
  final bool canDelete;

  factory EventComment.fromJson(Map<String, dynamic> json) {
    final isMine = json['is_mine'] as bool? ?? false;
    return EventComment(
      id: json['id'] as String,
      body: json['body'] as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Family member',
      isMine: isMine,
      canEdit: json['can_edit'] as bool? ?? isMine,
      canDelete: json['can_delete'] as bool? ?? isMine,
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
    this.coverPhotoDisplayUrl,
    required this.rsvpSummary,
    this.viewerRsvp,
    required this.rsvpAttendees,
    required this.comments,
  });

  final String? coverPhotoDisplayUrl;
  final RsvpSummary rsvpSummary;
  final String? viewerRsvp;
  final List<RsvpAttendee> rsvpAttendees;
  final List<EventComment> comments;

  EventDetail copyWith({
    String? coverPhotoDisplayUrl,
    RsvpSummary? rsvpSummary,
    String? viewerRsvp,
    List<RsvpAttendee>? rsvpAttendees,
    List<EventComment>? comments,
  }) {
    return EventDetail(
      id: id,
      title: title,
      description: description,
      startsAt: startsAt,
      endsAt: endsAt,
      location: location,
      videoCallUrl: videoCallUrl,
      coverPhotoId: coverPhotoId,
      coverPhotoDisplayUrl: coverPhotoDisplayUrl ?? this.coverPhotoDisplayUrl,
      rsvpSummary: rsvpSummary ?? this.rsvpSummary,
      viewerRsvp: viewerRsvp ?? this.viewerRsvp,
      rsvpAttendees: rsvpAttendees ?? this.rsvpAttendees,
      comments: comments ?? this.comments,
    );
  }

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
      coverPhotoDisplayUrl: json['cover_photo_display_url'] as String?,
      rsvpSummary: RsvpSummary.fromJson(
        json['rsvp_summary'] as Map<String, dynamic>? ?? {},
      ),
      viewerRsvp: json['viewer_rsvp'] as String?,
      rsvpAttendees: (json['rsvp_attendees'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RsvpAttendee.fromJson)
          .toList(),
      comments: commentsRaw is List
          ? commentsRaw
              .whereType<Map<String, dynamic>>()
              .map(EventComment.fromJson)
              .toList()
          : [],
    );
  }
}
