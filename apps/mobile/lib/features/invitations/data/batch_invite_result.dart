import '../domain/invitation_status.dart';

class BatchInviteRowResult {
  const BatchInviteRowResult({
    required this.email,
    required this.status,
    this.invitationId,
  });

  final String email;

  /// Null when the server sent a status this build does not know.
  final InviteRowStatus? status;
  final String? invitationId;

  factory BatchInviteRowResult.fromJson(Map<String, dynamic> json) {
    return BatchInviteRowResult(
      email: json['email'] as String? ?? '',
      status: InviteRowStatus.fromApi(json['status'] as String?),
      invitationId: json['invitation_id']?.toString(),
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

  int get emailQueueFailedCount => results
      .where((r) => r.status == InviteRowStatus.emailQueueFailed)
      .length;
}
