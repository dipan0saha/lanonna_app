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
    );
  }
}
