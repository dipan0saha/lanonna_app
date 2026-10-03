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
  });

  final String id;
  final String name;
  final String? gender;
  final String? expectedBirthDate;
  final String? actualBirthDate;
  final String lifecycleStatus;
  final String role;
  final String? avatarUrl;

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
    );
  }
}
