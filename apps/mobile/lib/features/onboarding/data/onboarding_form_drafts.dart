class CompleteProfileDraft {
  const CompleteProfileDraft({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.birthDateIso,
    this.countryCode,
    this.postalCode = '',
    this.relationshipLabel,
    this.termsAccepted = false,
    this.photoPath,
    this.networkPhotoUrl,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String? birthDateIso;
  final String? countryCode;
  final String postalCode;
  final String? relationshipLabel;
  final bool termsAccepted;
  final String? photoPath;
  final String? networkPhotoUrl;

  /// Legacy single-field name (migrated on read).
  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        if (birthDateIso != null) 'birthDateIso': birthDateIso,
        if (countryCode != null) 'countryCode': countryCode,
        'postalCode': postalCode,
        if (relationshipLabel != null) 'relationshipLabel': relationshipLabel,
        'termsAccepted': termsAccepted,
        if (photoPath != null) 'photoPath': photoPath,
        if (networkPhotoUrl != null) 'networkPhotoUrl': networkPhotoUrl,
      };

  static CompleteProfileDraft fromJson(Map<String, dynamic> json) {
    var first = json['firstName'] as String? ?? '';
    var last = json['lastName'] as String? ?? '';
    final legacy = json['fullName'] as String? ?? '';
    if (first.isEmpty && legacy.isNotEmpty) {
      final parts = legacy.trim().split(RegExp(r'\s+'));
      first = parts.first;
      if (parts.length > 1) {
        last = parts.sublist(1).join(' ');
      }
    }
    return CompleteProfileDraft(
      firstName: first,
      lastName: last,
      phone: json['phone'] as String? ?? '',
      birthDateIso: json['birthDateIso'] as String?,
      countryCode: json['countryCode'] as String?,
      postalCode: json['postalCode'] as String? ?? '',
      relationshipLabel: json['relationshipLabel'] as String?,
      termsAccepted: json['termsAccepted'] as bool? ?? false,
      photoPath: json['photoPath'] as String?,
      networkPhotoUrl: json['networkPhotoUrl'] as String?,
    );
  }
}

class AuthEmailDraft {
  const AuthEmailDraft({this.email = ''});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};

  static AuthEmailDraft fromJson(Map<String, dynamic> json) {
    return AuthEmailDraft(email: json['email'] as String? ?? '');
  }
}

class InviteRowDraft {
  const InviteRowDraft({
    this.name = '',
    this.email = '',
    this.relationshipPickerLabel = 'Grandma',
  });

  final String name;
  final String email;
  final String relationshipPickerLabel;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'relationshipPickerLabel': relationshipPickerLabel,
      };

  static InviteRowDraft fromJson(Map<String, dynamic> json) {
    return InviteRowDraft(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      relationshipPickerLabel:
          json['relationshipPickerLabel'] as String? ?? 'Grandma',
    );
  }
}

class BatchInviteDraft {
  const BatchInviteDraft({this.rows = const [InviteRowDraft()]});

  final List<InviteRowDraft> rows;

  Map<String, dynamic> toJson() => {
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  static BatchInviteDraft fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) {
      return const BatchInviteDraft();
    }
    return BatchInviteDraft(
      rows: raw
          .map((e) => InviteRowDraft.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
