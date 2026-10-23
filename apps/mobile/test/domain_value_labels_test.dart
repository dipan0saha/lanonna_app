import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/time/app_date_time.dart';
import 'package:lanonna/core/domain/person_display_label.dart';
import 'package:lanonna/core/domain/rsvp_status.dart';
import 'package:lanonna/features/account/domain/data_export_status.dart';
import 'package:lanonna/features/account/domain/notification_digest.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/core/domain/relationship_preset.dart';
import 'package:lanonna/l10n/app_localizations.dart';

/// Every server-owned enum parses its API value and shows localized copy,
/// never the raw API token.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  void expectLocalized<T extends Enum>(
    List<T> values,
    String Function(T) apiValue,
    T? Function(String) fromApi,
    String Function(T) label,
  ) {
    for (final v in values) {
      expect(fromApi(apiValue(v)), v, reason: 'round-trips ${apiValue(v)}');
      final text = label(v);
      expect(text, isNotEmpty);
      expect(text, isNot(apiValue(v)), reason: '$v shows its raw API value');
    }
  }

  test('baby lifecycle', () {
    expectLocalized(BabyLifecycle.values, (v) => v.apiValue,
        BabyLifecycle.fromApi, (v) => v.label(l10n));
    expect(BabyLifecycle.fromApi(null), BabyLifecycle.expecting);
    expect(BabyLifecycle.born.label(l10n), 'Born');
  });

  test('baby gender', () {
    expectLocalized(BabyGender.values, (v) => v.apiValue, BabyGender.fromApi,
        (v) => v.label(l10n));
    expect(BabyGender.fromApi('other'), BabyGender.unknown);
  });

  test('data export status', () {
    expectLocalized(DataExportStatus.values, (v) => v.apiValue,
        DataExportStatus.fromApi, (v) => v.label(l10n));
  });

  test('invitation and invite email status', () {
    expectLocalized(InvitationStatus.values, (v) => v.apiValue,
        InvitationStatus.fromApi, (v) => v.label(l10n));
    expect(InvitationStatus.fromApi(null), InvitationStatus.expired);
    expectLocalized(InviteEmailDeliveryStatus.values, (v) => v.apiValue,
        InviteEmailDeliveryStatus.fromApi, (v) => v.label(l10n));
    expect(InviteEmailDeliveryStatus.fromApi(null), isNull);
  });

  test('rsvp status', () {
    expectLocalized(RsvpStatus.values, (v) => v.apiValue, RsvpStatus.fromApi,
        (v) => v.label(l10n));
    expect(RsvpStatus.cantGo.label(l10n), "Can't go");
  });

  test('notification digest option and summary labels', () {
    expectLocalized(NotificationDigest.values, (v) => v.apiValue,
        NotificationDigest.fromApi, (v) => v.label(l10n));
    expectLocalized(NotificationDigest.values, (v) => v.apiValue,
        NotificationDigest.fromApi, (v) => v.summaryLabel(l10n));
    expect(NotificationDigest.fromApi('unknown'), NotificationDigest.realtime);
    expect(NotificationDigest.weekly.summaryLabel(l10n), 'Weekly push summary');
    // Daily has no scheduled send (FR-NOTIF-002); the copy must not promise one.
    expect(NotificationDigest.daily.summaryLabel(l10n), 'Inbox only, no push');
  });

  test('relationship presets store canonical labels and show localized ones', () {
    for (final p in RelationshipPreset.values) {
      expect(p.label(l10n), isNotEmpty);
      expect(RelationshipPreset.fromDraft(p.name), p);
    }
    expect(RelationshipPreset.wife.membershipLabel, 'Mother');
    expect(RelationshipPreset.wife.label(l10n), 'Wife');
    expect(RelationshipPreset.wife.grantsCoOwner, isTrue);
    expect(RelationshipPreset.grandma.grantsCoOwner, isFalse);
    expect(RelationshipPreset.fromDraft('Grandma'), RelationshipPreset.initial);
    expect(
      RelationshipPreset.onboardingOptions,
      isNot(contains(RelationshipPreset.mother)),
    );
  });

  test('stored relationship labels display in the viewer locale', () {
    expect(RelationshipPreset.fromMembershipLabel('Mother'), RelationshipPreset.mother);
    expect(RelationshipPreset.fromMembershipLabel(' grandma '), RelationshipPreset.grandma);
    expect(RelationshipPreset.fromMembershipLabel('Family Friend'),
        RelationshipPreset.familyFriend);
    expect(RelationshipPreset.fromMembershipLabel('Neighbour'), isNull);
    for (final p in RelationshipPreset.appOptions) {
      expect(relationshipDisplayLabel(l10n, p.membershipLabel), p.label(l10n));
    }
    // Wife/Husband store Mother/Father and read back as those.
    expect(
      relationshipDisplayLabel(l10n, RelationshipPreset.wife.membershipLabel),
      l10n.relationshipMother,
    );
    expect(relationshipDisplayLabel(l10n, ' Neighbour '), 'Neighbour');
    expect(relationshipDisplayLabel(l10n, '  '), isNull);
    expect(relationshipDisplayLabel(l10n, null), isNull);
  });

  test('invite row status and membership hints are typed values', () {
    for (final s in InviteRowStatus.values) {
      expect(InviteRowStatus.fromApi(s.apiValue), s);
    }
    expect(InviteRowStatus.fromApi('skipped_invalid'), isNull);
    expect(
      InviteMembershipHint.fromCheck(isMember: true, hasPendingInvite: true),
      InviteMembershipHint.alreadyMember,
    );
    expect(
      InviteMembershipHint.fromCheck(isMember: false, hasPendingInvite: true),
      InviteMembershipHint.invitePending,
    );
    expect(
      InviteMembershipHint.fromCheck(isMember: false, hasPendingInvite: false),
      isNull,
    );
    expect(
      InviteMembershipHint.alreadyMember.label(l10n),
      l10n.invitationsAlreadyOnTheFamily,
    );
  });

  test('personDisplayName falls back for missing names', () {
    expect(personDisplayName(l10n, ' Ada '), 'Ada');
    expect(personDisplayName(l10n, ''), l10n.personNameFallback);
    expect(personDisplayName(l10n, null), l10n.personNameFallback);
  });

  test('formatRelativeTime pluralizes through the ARB', () {
    final now = DateTime.now();
    expect(formatRelativeTime(l10n, now), l10n.relativeTimeJustNow);
    expect(
      formatRelativeTime(l10n, now.subtract(const Duration(minutes: 1))),
      '1 minute ago',
    );
    expect(
      formatRelativeTime(l10n, now.subtract(const Duration(minutes: 5))),
      '5 minutes ago',
    );
    expect(
      formatRelativeTime(l10n, now.subtract(const Duration(days: 3))),
      '3 days ago',
    );
  });

  test('calendar month helpers use locale date formats', () {
    expect(formatMonthYear(DateTime(2026, 3, 5), 'en_US'), 'March 2026');
    expect(formatMonthDay(DateTime(2026, 3, 5), 'en_US'), 'March 5');
    expect(calendarWeekdayHeaders(l10n), hasLength(7));
  });
}
