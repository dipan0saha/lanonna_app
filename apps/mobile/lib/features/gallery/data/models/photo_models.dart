class PhotoSummary {
  PhotoSummary({
    required this.id,
    required this.status,
    this.caption,
    required this.createdAt,
    this.thumbUrl,
    required this.squishCount,
    required this.commentCount,
    required this.uploaderDisplayName,
  });

  final String id;
  final String status;
  final String? caption;
  final DateTime createdAt;
  final String? thumbUrl;
  final int squishCount;
  final int commentCount;
  final String uploaderDisplayName;

  factory PhotoSummary.fromJson(Map<String, dynamic> json) {
    return PhotoSummary(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      thumbUrl: json['thumb_url'] as String?,
      squishCount: json['squish_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      uploaderDisplayName:
          json['uploader_display_name'] as String? ?? 'Family member',
    );
  }
}

class PhotoTaggedBaby {
  PhotoTaggedBaby({required this.id, required this.name});

  final String id;
  final String name;

  factory PhotoTaggedBaby.fromJson(Map<String, dynamic> json) {
    return PhotoTaggedBaby(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Baby',
    );
  }
}

class PhotoComment {
  PhotoComment({
    required this.id,
    required this.body,
    required this.authorDisplayName,
    required this.createdAt,
    required this.isMine,
    required this.canEdit,
    required this.canDelete,
  });

  final String id;
  final String body;
  final String authorDisplayName;
  final DateTime createdAt;
  final bool isMine;
  final bool canEdit;
  final bool canDelete;

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    final isMine = json['is_mine'] as bool? ?? false;
    return PhotoComment(
      id: json['id'] as String,
      body: json['body'] as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Family member',
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: isMine,
      canEdit: json['can_edit'] as bool? ?? isMine,
      canDelete: json['can_delete'] as bool? ?? isMine,
    );
  }
}

class PhotoDetail {
  PhotoDetail({
    required this.id,
    required this.status,
    this.caption,
    required this.createdAt,
    this.displayUrl,
    this.thumbUrl,
    required this.uploaderDisplayName,
    required this.squishCount,
    required this.viewerHasSquished,
    required this.comments,
    required this.taggedBabies,
  });

  final String id;
  final String status;
  final String? caption;
  final DateTime createdAt;
  final String? displayUrl;
  final String? thumbUrl;
  final String uploaderDisplayName;
  final int squishCount;
  final bool viewerHasSquished;
  final List<PhotoComment> comments;
  final List<PhotoTaggedBaby> taggedBabies;

  PhotoDetail copyWith({
    String? caption,
    int? squishCount,
    bool? viewerHasSquished,
    List<PhotoComment>? comments,
    List<PhotoTaggedBaby>? taggedBabies,
  }) {
    return PhotoDetail(
      id: id,
      status: status,
      caption: caption ?? this.caption,
      createdAt: createdAt,
      displayUrl: displayUrl,
      thumbUrl: thumbUrl,
      uploaderDisplayName: uploaderDisplayName,
      squishCount: squishCount ?? this.squishCount,
      viewerHasSquished: viewerHasSquished ?? this.viewerHasSquished,
      comments: comments ?? this.comments,
      taggedBabies: taggedBabies ?? this.taggedBabies,
    );
  }

  factory PhotoDetail.fromJson(Map<String, dynamic> json) {
    final commentsRaw = json['comments'];
    final taggedRaw = json['tagged_babies'];
    return PhotoDetail(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'ready',
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      displayUrl: json['display_url'] as String?,
      thumbUrl: json['thumb_url'] as String?,
      uploaderDisplayName:
          json['uploader_display_name'] as String? ?? 'Family member',
      squishCount: json['squish_count'] as int? ?? 0,
      viewerHasSquished: json['viewer_has_squished'] as bool? ?? false,
      comments: commentsRaw is List
          ? commentsRaw
              .whereType<Map<String, dynamic>>()
              .map(PhotoComment.fromJson)
              .toList()
          : [],
      taggedBabies: taggedRaw is List
          ? taggedRaw
              .whereType<Map<String, dynamic>>()
              .map(PhotoTaggedBaby.fromJson)
              .toList()
          : [],
    );
  }
}
