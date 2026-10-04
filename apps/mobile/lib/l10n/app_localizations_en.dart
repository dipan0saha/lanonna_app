// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle =>
      'Digest, push, and channel preferences';

  @override
  String get settingsHelpSupport => 'Help & support';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get notificationChannelGallery => 'Gallery';

  @override
  String get notificationChannelGallerySubtitle =>
      'New photos, squishes, and photo comments';

  @override
  String get notificationChannelCalendar => 'Calendar';

  @override
  String get notificationChannelCalendarSubtitle => 'New events and RSVPs';

  @override
  String get notificationChannelRegistry => 'Registry';

  @override
  String get notificationChannelRegistrySubtitle =>
      'Registry purchases and updates';

  @override
  String get notificationChannelComments => 'Event comments';

  @override
  String get notificationChannelCommentsSubtitle =>
      'Comments on calendar events';

  @override
  String get notificationPrefsSave => 'Save';

  @override
  String get notificationPrefsSaving => 'Saving…';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountBody =>
      'This permanently deletes your La Nonna account. Any Baby Profiles solely owned by your account will also be deleted. Baby Profiles with a co owner will not be deleted; ownership will transfer fully to the co owner.';

  @override
  String get deleteAccountButton => 'Delete my account';

  @override
  String get deleteAccountDeleting => 'Deleting…';

  @override
  String get emailVerifyHeadline => 'Check your email';

  @override
  String emailVerifyBody(String email) {
    return 'We sent a message to $email with a Verify my email button. Tap it to activate your account. If you do not see it, check spam or junk.';
  }

  @override
  String get emailVerifyOAuthNote => 'Google sign-up skips this step.';

  @override
  String get emailVerifyContinuePending =>
      'Not verified yet — open the newest email and tap Verify my email, then try Continue.';

  @override
  String get emailVerifySent => 'Verification email sent.';

  @override
  String get emailVerifyResend => 'Resend email';
}
