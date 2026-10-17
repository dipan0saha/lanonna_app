import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/name_suggestion_draft.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';

class CreateBabyDraft {
  const CreateBabyDraft({
    this.lifecycle = BabyLifecycle.expecting,
    this.gender = BabyGender.unknown,
    this.dateIso,
    this.boyName = '',
    this.girlName = '',
    this.photoPath,
    this.sharePhotoToGallery = false,
  });

  final BabyLifecycle lifecycle;
  final BabyGender gender;
  final String? dateIso;
  final String boyName;
  final String girlName;
  final String? photoPath;
  final bool sharePhotoToGallery;

  Map<String, dynamic> toJson() => {
        'lifecycle': lifecycle.apiValue,
        'gender': gender.apiValue,
        if (dateIso != null) 'dateIso': dateIso,
        'boyName': boyName,
        'girlName': girlName,
        if (photoPath != null) 'photoPath': photoPath,
        if (sharePhotoToGallery) 'sharePhotoToGallery': sharePhotoToGallery,
      };

  static CreateBabyDraft fromJson(Map<String, dynamic> json) {
    return CreateBabyDraft(
      lifecycle: BabyLifecycle.fromApi(json['lifecycle'] as String?),
      gender: json.containsKey('gender')
          ? BabyGender.fromApi(json['gender'] as String?)
          : _legacyPillGender(json['genderPill'] as String?),
      dateIso: json['dateIso'] as String?,
      boyName: json['boyName'] as String? ?? '',
      girlName: json['girlName'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      sharePhotoToGallery: json['sharePhotoToGallery'] as bool? ?? false,
    );
  }
}

/// Drafts saved before gender was stored as an API value kept the English pill
/// label; map those once so in-progress onboarding survives the upgrade.
BabyGender _legacyPillGender(String? pill) => switch (pill) {
      'Boy' => BabyGender.male,
      'Girl' => BabyGender.female,
      _ => BabyGender.unknown,
    };

class FirstMomentDraft {
  const FirstMomentDraft({
    this.selectedEvents = const [],
    this.selectedRegistry = const [],
    this.nameDrafts = const [],
    this.nameInput = '',
    this.nameGender = BabyGender.male,
    this.photoPath,
  });

  final List<String> selectedEvents;
  final List<String> selectedRegistry;
  final List<NameSuggestionDraft> nameDrafts;
  final String nameInput;
  final BabyGender nameGender;
  final String? photoPath;

  Map<String, dynamic> toJson() => {
        'selectedEvents': selectedEvents,
        'selectedRegistry': selectedRegistry,
        'nameDrafts': nameDrafts.map((d) => d.toJson()).toList(),
        'nameInput': nameInput,
        'nameGender': nameGender.apiValue,
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
              ?.whereType<Map<dynamic, dynamic>>()
              .map(NameSuggestionDraft.fromJson)
              .toList() ??
          const [],
      nameInput: json['nameInput'] as String? ?? '',
      nameGender:
          nameIdeaGender(BabyGender.fromApi(json['nameGender'] as String?)),
      photoPath: json['photoPath'] as String?,
    );
  }
}
