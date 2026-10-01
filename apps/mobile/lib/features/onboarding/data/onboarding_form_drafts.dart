class CompleteProfileDraft {
  const CompleteProfileDraft({
    this.fullName = '',
    this.termsAccepted = true,
    this.photoPath,
    this.networkPhotoUrl,
  });

  final String fullName;
  final bool termsAccepted;
  final String? photoPath;
  final String? networkPhotoUrl;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'termsAccepted': termsAccepted,
        if (photoPath != null) 'photoPath': photoPath,
        if (networkPhotoUrl != null) 'networkPhotoUrl': networkPhotoUrl,
      };

  static CompleteProfileDraft fromJson(Map<String, dynamic> json) {
    return CompleteProfileDraft(
      fullName: json['fullName'] as String? ?? '',
      termsAccepted: json['termsAccepted'] as bool? ?? true,
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
