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
  String get deleteAccountChecking =>
      'Checking whether your account can be deleted…';

  @override
  String get deleteAccountBlocked =>
      'Your account cannot be deleted right now.';

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
      'Not verified yet - open the newest email and tap Verify my email, then try Continue.';

  @override
  String get emailVerifySent => 'Verification email sent.';

  @override
  String get emailVerifyResend => 'Resend email';

  @override
  String photoSquishCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count squishes',
      one: '1 squish',
      zero: '0 squishes',
    );
    return '$_temp0';
  }

  @override
  String photoCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: '0 comments',
    );
    return '$_temp0';
  }

  @override
  String predictionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: '0 votes',
    );
    return '$_temp0';
  }

  @override
  String nameLoveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loves',
      one: '1 love',
      zero: '0 loves',
    );
    return '$_temp0';
  }

  @override
  String registryItemsStillNeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items still needed',
      one: '1 item still needed',
      zero: '0 items still needed',
    );
    return '$_temp0';
  }

  @override
  String funBirthdateYourGuess(String date) {
    return 'Your guess: $date';
  }

  @override
  String funBirthdateSelected(String date) {
    return 'Selected: $date';
  }

  @override
  String funBirthdateDueDate(String label) {
    return 'Due date: $label';
  }

  @override
  String get funBirthdateSaveGuess => 'Save guess';

  @override
  String get funBirthdateUpdateGuess => 'Update guess';

  @override
  String get funBirthdatePickDate => 'Pick date…';

  @override
  String get funBirthdateConfirmSaveTitle => 'Save birthdate guess?';

  @override
  String funBirthdateConfirmSaveBody(String date) {
    return 'Your guess will be $date. You can change it later.';
  }

  @override
  String get funBirthdateConfirmUpdateTitle => 'Update birthdate guess?';

  @override
  String funBirthdateConfirmUpdateBody(String date) {
    return 'Change your guess to $date?';
  }

  @override
  String get funBirthdateConfirmAction => 'Save';

  @override
  String get rsvpStatusGoing => 'Going';

  @override
  String get rsvpStatusMaybe => 'Maybe';

  @override
  String get rsvpStatusCantGo => 'Can\'t go';

  @override
  String eventRsvpCountWithStatus(int count, String status) {
    return '$count $status';
  }

  @override
  String eventRsvpViewAllTeaser(String goingPart, String maybePart) {
    return '$goingPart · $maybePart - View RSVPs ›';
  }

  @override
  String get authPasswordResetForgotLink => 'Forgot password?';

  @override
  String get authPasswordResetDialogTitle => 'Reset password';

  @override
  String get authPasswordResetDialogBody =>
      'Enter the email for your account. We\'ll send a reset link.';

  @override
  String get authPasswordResetEmailLabel => 'Email';

  @override
  String get authPasswordResetSend => 'Send reset link';

  @override
  String get authPasswordResetCancel => 'Cancel';

  @override
  String get authPasswordResetSent =>
      'Check your email for a password reset link.';

  @override
  String get memberRemoveConfirmTitle => 'Remove from family?';

  @override
  String memberRemoveConfirmBody(String name) {
    return '$name will lose access to photos, events, and registry for this baby.';
  }

  @override
  String get memberRemoveAction => 'Remove';

  @override
  String get memberLeaveProfile => 'Leave profile';

  @override
  String get memberLeaveConfirmTitle => 'Leave this baby profile?';

  @override
  String get memberLeaveConfirmBody =>
      'You will lose access to this baby\'s photos, calendar, and registry.';

  @override
  String get memberLeaveAction => 'Leave';

  @override
  String get memberSoleOwnerLeaveTitle => 'Can\'t leave yet';

  @override
  String get memberSoleOwnerLeaveBody =>
      'You are the only owner. Add a co-owner, delete this baby profile, or delete your account to leave.';

  @override
  String get membershipEndedMessage =>
      'You no longer have access to this profile.';

  @override
  String get memberRemovedSuccess => 'Member removed.';

  @override
  String get memberLeftSuccess => 'You left this baby profile.';
}
