class BatchInviteRowResult {
  const BatchInviteRowResult({
    required this.email,
    required this.status,
    this.invitationId,
    this.message,
  });

  final String email;
  final String status;
  final String? invitationId;
  final String? message;

  factory BatchInviteRowResult.fromJson(Map<String, dynamic> json) {
    return BatchInviteRowResult(
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? '',
      invitationId: json['invitation_id']?.toString(),
      message: json['message'] as String?,
    );
  }
}

class BatchInviteResponse {
  const BatchInviteResponse({required this.results});

  final List<BatchInviteRowResult> results;

  factory BatchInviteResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    if (raw is! List) return const BatchInviteResponse(results: []);
    return BatchInviteResponse(
      results: raw
          .whereType<Map<String, dynamic>>()
          .map(BatchInviteRowResult.fromJson)
          .toList(),
    );
  }

  int get emailQueueFailedCount =>
      results.where((r) => r.status == 'email_queue_failed').length;
}
