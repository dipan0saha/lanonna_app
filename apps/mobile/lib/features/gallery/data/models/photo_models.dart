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

class PhotoComment {
  PhotoComment({
    required this.id,
    required this.body,
    required this.authorDisplayName,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String body;
  final String authorDisplayName;
  final DateTime createdAt;
  final bool isMine;

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    return PhotoComment(
      id: json['id'] as String,
      body: json['body'] as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Family member',
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
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

  factory PhotoDetail.fromJson(Map<String, dynamic> json) {
    final commentsRaw = json['comments'];
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
    );
  }
}
