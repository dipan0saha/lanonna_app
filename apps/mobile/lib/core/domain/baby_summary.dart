import 'baby_gender.dart';
import 'baby_lifecycle.dart';

class BabySummary {
  const BabySummary({
    required this.id,
    required this.name,
    required this.lifecycle,
    required this.role,
    this.gender = BabyGender.unknown,
    this.expectedBirthDate,
    this.actualBirthDate,
    this.avatarUrl,
    this.relationshipLabel,
    this.canLeave = true,
    this.namesClosed = false,
    this.predictionsClosed = false,
  });

  final String id;

  /// The name the owner entered; `null` while the baby has no name. Display
  /// through `babyNameLabel` / `babyDisplayName`, never directly.
  final String? name;
  final BabyGender gender;
  final String? expectedBirthDate;
  final String? actualBirthDate;
  final BabyLifecycle lifecycle;
  final String role;
  final String? avatarUrl;
  final String? relationshipLabel;
  final bool canLeave;
  final bool namesClosed;
  final bool predictionsClosed;

  bool get isBorn => lifecycle == BabyLifecycle.born;

  factory BabySummary.fromJson(Map<String, dynamic> json) {
    return BabySummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      gender: BabyGender.fromApi(json['gender'] as String?),
      expectedBirthDate: json['expected_birth_date']?.toString(),
      actualBirthDate: json['actual_birth_date']?.toString(),
      lifecycle: BabyLifecycle.fromApi(json['lifecycle_status'] as String?),
      role: json['role'] as String? ?? 'follower',
      avatarUrl: json['avatar_url'] as String?,
      relationshipLabel: json['relationship_label'] as String?,
      canLeave: json['can_leave'] as bool? ?? true,
      namesClosed: json['names_closed'] as bool? ?? false,
      predictionsClosed: json['predictions_closed'] as bool? ?? false,
    );
  }
}
