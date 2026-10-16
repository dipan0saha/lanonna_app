class BabySummary {
  const BabySummary({
    required this.id,
    required this.name,
    required this.lifecycleStatus,
    required this.role,
    this.gender,
    this.expectedBirthDate,
    this.actualBirthDate,
    this.avatarUrl,
    this.relationshipLabel,
    this.canLeave = true,
    this.namesClosed = false,
    this.predictionsClosed = false,
  });

  final String id;
  final String name;
  final String? gender;
  final String? expectedBirthDate;
  final String? actualBirthDate;
  final String lifecycleStatus;
  final String role;
  final String? avatarUrl;
  final String? relationshipLabel;
  final bool canLeave;
  final bool namesClosed;
  final bool predictionsClosed;

  bool get isBorn => lifecycleStatus == 'born';

  factory BabySummary.fromJson(Map<String, dynamic> json) {
    return BabySummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String?,
      expectedBirthDate: json['expected_birth_date']?.toString(),
      actualBirthDate: json['actual_birth_date']?.toString(),
      lifecycleStatus: json['lifecycle_status'] as String? ?? 'expecting',
      role: json['role'] as String? ?? 'follower',
      avatarUrl: json['avatar_url'] as String?,
      relationshipLabel: json['relationship_label'] as String?,
      canLeave: json['can_leave'] as bool? ?? true,
      namesClosed: json['names_closed'] as bool? ?? false,
      predictionsClosed: json['predictions_closed'] as bool? ?? false,
    );
  }
}
