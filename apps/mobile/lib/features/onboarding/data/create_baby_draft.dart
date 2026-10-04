class CreateBabyDraft {
  const CreateBabyDraft({
    this.lifecycle = 'expecting',
    this.genderPill = 'Not sure yet',
    this.dateIso,
    this.boyName = '',
    this.girlName = '',
    this.photoPath,
    this.sharePhotoToGallery = false,
  });

  final String lifecycle;
  final String genderPill;
  final String? dateIso;
  final String boyName;
  final String girlName;
  final String? photoPath;
  final bool sharePhotoToGallery;

  Map<String, dynamic> toJson() => {
        'lifecycle': lifecycle,
        'genderPill': genderPill,
        if (dateIso != null) 'dateIso': dateIso,
        'boyName': boyName,
        'girlName': girlName,
        if (photoPath != null) 'photoPath': photoPath,
        if (sharePhotoToGallery) 'sharePhotoToGallery': sharePhotoToGallery,
      };

  static CreateBabyDraft fromJson(Map<String, dynamic> json) {
    return CreateBabyDraft(
      lifecycle: json['lifecycle'] as String? ?? 'expecting',
      genderPill: json['genderPill'] as String? ?? 'Not sure yet',
      dateIso: json['dateIso'] as String?,
      boyName: json['boyName'] as String? ?? '',
      girlName: json['girlName'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      sharePhotoToGallery: json['sharePhotoToGallery'] as bool? ?? false,
    );
  }
}

class FirstMomentDraft {
  const FirstMomentDraft({
    this.selectedEvents = const [],
    this.selectedRegistry = const [],
    this.nameDrafts = const [],
    this.nameInput = '',
    this.nameGender = 'male',
    this.photoPath,
  });

  final List<String> selectedEvents;
  final List<String> selectedRegistry;
  final List<Map<String, String>> nameDrafts;
  final String nameInput;
  final String nameGender;
  final String? photoPath;

  Map<String, dynamic> toJson() => {
        'selectedEvents': selectedEvents,
        'selectedRegistry': selectedRegistry,
        'nameDrafts': nameDrafts,
        'nameInput': nameInput,
        'nameGender': nameGender,
        if (photoPath != null) 'photoPath': photoPath,
      };

  static FirstMomentDraft fromJson(Map<String, dynamic> json) {
    return FirstMomentDraft(
      selectedEvents: (json['selectedEvents'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      selectedRegistry: (json['selectedRegistry'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      nameDrafts: (json['nameDrafts'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          const [],
      nameInput: json['nameInput'] as String? ?? '',
      nameGender: json['nameGender'] as String? ?? 'male',
      photoPath: json['photoPath'] as String?,
    );
  }
}
