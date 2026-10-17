import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/rsvp_status.dart';
import 'package:lanonna/features/account/domain/data_export_status.dart';
import 'package:lanonna/features/account/domain/notification_digest.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
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
    expect(NotificationDigest.weekly.summaryLabel(l10n), 'Weekly email summary');
  });
}
