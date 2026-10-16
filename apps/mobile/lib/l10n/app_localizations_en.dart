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
  String get settingsBiometricUnlock => 'Use biometric unlock';

  @override
  String get settingsBiometricUnlockSubtitle =>
      'Require Face ID or fingerprint to open the app after you sign in';

  @override
  String get settingsBiometricUnavailable =>
      'Biometrics are not available on this device.';

  @override
  String get biometricUnlockReason => 'Unlock La Nonna';

  @override
  String get biometricUnlockTitle => 'Locked';

  @override
  String get biometricUnlockRetry => 'Try again';

  @override
  String get biometricUnlockSignOut => 'Sign out';

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
  String get deleteAccountConfirmTitle => 'Delete your account permanently?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently deletes your La Nonna account. Any Baby Profiles solely owned by your account will also be deleted. Baby Profiles with a co owner will not be deleted; ownership will transfer fully to the co owner.';

  @override
  String get deleteAccountConfirmAction => 'Delete account';

  @override
  String get deleteAccountSoleOwnedHeading =>
      'These baby profiles will be deleted:';

  @override
  String get deleteAccountReauthPasswordTitle => 'Confirm your password';

  @override
  String get deleteAccountReauthPasswordBody =>
      'Enter your password to delete your account.';

  @override
  String get deleteAccountReauthPasswordAction => 'Continue';

  @override
  String get deleteAccountReauthFailed =>
      'Please sign in again to delete your account.';

  @override
  String get emailVerifyHeadline => 'Check your email';

  @override
  String emailVerifyBody(String email) {
    return 'We sent a message to $email with a Verify my email button. Tap it to activate your account. If you do not see it, check spam or junk.';
  }

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
  String rsvpResponseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count responses',
      one: '1 response',
      zero: '0 responses',
    );
    return '$_temp0';
  }

  @override
  String notificationPreferencesIntro(String babyName) {
    return 'Choose how often you\'d like updates from $babyName.';
  }

  @override
  String get aiSuggestionsSubtitle =>
      'Pick a stage, then add suggestions to your calendar or registry.';

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
  String get predictionsClosedNote => 'Predictions closed — baby has arrived';

  @override
  String get namesClosedNote => 'Name ideas are closed — baby has arrived.';

  @override
  String get rsvpStatusGoing => 'Going';

  @override
  String get rsvpStatusMaybe => 'Maybe';

  @override
  String get rsvpStatusCantGo => 'Can\'t go';

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
  String get authErrorIncorrectCredentials =>
      'Incorrect email or password. Try again or reset your password.';

  @override
  String get authErrorInvalidEmail => 'Enter a valid email address.';

  @override
  String get authErrorUserDisabled =>
      'This account has been disabled. Contact support for help.';

  @override
  String get authErrorEmailAlreadyInUse =>
      'An account already exists with this email. Sign in instead.';

  @override
  String get authErrorWeakPassword =>
      'Choose a stronger password (at least 6 characters).';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get authErrorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get authErrorOperationNotAllowed =>
      'This sign-in method isn\'t available. Try email and password.';

  @override
  String get authErrorAccountExistsDifferentCredential =>
      'An account already exists with a different sign-in method. Try email and password.';

  @override
  String get authErrorPasswordResetIfAccountExists =>
      'If an account exists for this email, you\'ll receive a password reset link.';

  @override
  String get authErrorGenericSignIn => 'Could not sign in. Please try again.';

  @override
  String get authErrorGenericSignUp =>
      'Could not create your account. Please try again.';

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

  @override
  String get appTitle => 'La Nonna';

  @override
  String get appEmailVerifiedSignIn =>
      'Email verified. Sign in with the same address to continue.';

  @override
  String get appEmailVerifyLinkFailed =>
      'Could not verify your email from this link.';

  @override
  String get batchInviteCoOwnerHintOnboarding =>
      'Selecting Wife or Husband makes that person a co-owner with the same edit access as you.';

  @override
  String get batchInviteCoOwnerHintManage =>
      '💡 Selecting \"Mother\" or \"Father\" makes that person a co-owner of this baby profile, with the same edit access as you.';

  @override
  String get batchInviteNoInvitesToSend => 'No invites to send.';

  @override
  String get batchInviteAddEmailToSend =>
      'Add at least one email address to send invites.';

  @override
  String get batchInviteInvalidEmails =>
      'Enter a valid email for each invite row.';

  @override
  String get batchInviteNoNewInvites =>
      'No new invites to send for the emails entered.';

  @override
  String batchInviteEmailQueueFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count invites were saved but emails could not be sent. Check Manage followers.',
      one:
          'One invite was saved but the email could not be sent. Check Manage followers.',
    );
    return '$_temp0';
  }

  @override
  String get wrongEmailHeadline => 'Wrong account';

  @override
  String wrongEmailBody(String invitee, String signedIn) {
    return 'This invitation was sent to $invitee, but you\'re signed in as $signedIn. Sign in with the invited email to continue.';
  }

  @override
  String get wrongEmailInviteeFallback => 'the invited email';

  @override
  String get wrongEmailSwitchAccount => 'Switch account';

  @override
  String get wrongEmailLeaveInvitation => 'Leave this invitation';

  @override
  String predictionGenderVoteShare(int pct, int count) {
    return '$pct% ($count)';
  }

  @override
  String get commentComposerHint => 'Add a comment…';

  @override
  String get commentSend => 'Send comment';

  @override
  String get commentEditTitle => 'Edit comment';

  @override
  String get commentEditHint => 'Comment';

  @override
  String get commentDeleteTitle => 'Delete comment?';

  @override
  String get commentSave => 'Save';

  @override
  String get commentCancel => 'Cancel';

  @override
  String get commentDeleteAction => 'Delete';

  @override
  String followerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count followers',
      one: '1 follower',
      zero: '0 followers',
    );
    return '$_temp0';
  }

  @override
  String get actionRetry => 'Retry';

  @override
  String get babyNameFallback => 'your baby';

  @override
  String get notificationsInboxTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsInboxEmptyTitle => 'No notifications yet';

  @override
  String get notificationsInboxEmptyMessage =>
      'When family comments, RSVPs, or joins, you\'ll see it here.';

  @override
  String get inboxNotificationFallbackTitle => 'Notification';

  @override
  String get accountDigestFrequency => 'Digest frequency';

  @override
  String get homeBornActivityEmpty =>
      'Nothing yet. Once family starts commenting and squishing photos, you\'ll see it here.';

  @override
  String get calendarPastEventsTitle => 'Past events';

  @override
  String get calendarPastEventsSubtitle => 'Events that have already happened';

  @override
  String get calendarPastEventsEmpty => 'No past events yet.';

  @override
  String get calendarLoadMore => 'Load more';

  @override
  String get registrySortPriorityHighFirst => 'Priority: High first';

  @override
  String get registrySortPriorityLowFirst => 'Priority: Low first';

  @override
  String get versionGateUpdateInStore => 'Update in store';

  @override
  String get aiSuggestionsTitle => 'AI Suggestions';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get accountDateOfBirthOptional => 'Date of birth (optional)';

  @override
  String get accountAddNewBaby => '+ Add New';

  @override
  String get accountManageFollowers => 'Manage Followers';

  @override
  String get accountInviteFamily => 'Invite Family';

  @override
  String get accountExportBabyData => 'Export baby data';

  @override
  String get exportDownload => 'Download export';

  @override
  String get exportRefreshStatus => 'Refresh status';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get followersEmpty => 'No followers yet — invite family to join.';

  @override
  String get actionRevoke => 'Revoke';

  @override
  String get actionResend => 'Resend';

  @override
  String get notificationPrefsPushTitle => 'Push notifications';

  @override
  String get notificationPrefsPushSubtitle => 'Get alerts on your phone';

  @override
  String get notificationPrefsDigestTitle => 'Weekly email digest';

  @override
  String get notificationPrefsDigestSubtitle =>
      'Photos, events and registry updates';

  @override
  String get actionEdit => 'Edit';

  @override
  String get accountLogOut => 'Log Out';

  @override
  String get announcementDateOfBirth => 'Date of birth';

  @override
  String get announcementTimeOfBirth => 'Time of birth';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get noBabyProfileYet => 'No baby profile yet.';

  @override
  String get calendarPastButton => 'Past';

  @override
  String get calendarUpcomingTitle => 'Upcoming events';

  @override
  String get eventNoRsvps => 'No RSVPs yet';

  @override
  String get eventDeleteConfirmTitle => 'Delete this event?';

  @override
  String get eventDeleteConfirmBody =>
      'Family will no longer see it on the calendar.';

  @override
  String get actionDelete => 'Delete';

  @override
  String get eventNotFound => 'Event not found';

  @override
  String get eventJoinVideoCall => 'Join video call';

  @override
  String get eventPhotoLabel => 'Photo';

  @override
  String get eventCoverUploadNew => 'Upload new photo';

  @override
  String get eventCoverNone => 'No cover photo';

  @override
  String get actionShowAll => 'Show all';

  @override
  String get calendarAddEvent => 'Add event';

  @override
  String get funRemoveNameTitle => 'Remove name suggestion?';

  @override
  String funRemoveNameBody(String name) {
    return 'Remove \"$name\" from the list?';
  }

  @override
  String get actionRemove => 'Remove';

  @override
  String get funGenderBoy => 'Boy';

  @override
  String get funGenderGirl => 'Girl';

  @override
  String get actionAdd => 'Add';

  @override
  String get funViewWhoVoted => 'View who voted';

  @override
  String get photoDeleteConfirmTitle => 'Delete this photo?';

  @override
  String get photoNotFound => 'Photo not found';

  @override
  String get photoProcessing => 'Processing…';

  @override
  String get actionSave => 'Save';

  @override
  String get photoSourceCamera => 'Take photo';

  @override
  String get photoSourceLibrary => 'Choose from library';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionPost => 'Post';

  @override
  String get photoUnavailable => 'Unavailable';

  @override
  String get homeCreateAnnouncementTitle => 'Create announcement?';

  @override
  String get actionLater => 'Later';

  @override
  String get actionCreate => 'Create';

  @override
  String get activityTitle => 'Activity';

  @override
  String get actionLoadMore => 'Load more';

  @override
  String get actionManageFollowers => 'Manage followers';

  @override
  String get actionDismiss => 'Dismiss';

  @override
  String get onboardingHaveAccount => 'I already have an account';

  @override
  String get onboardingContinueWithGoogle => 'Continue with Google';

  @override
  String get onboardingAgreePrefix => 'I agree to the ';

  @override
  String get onboardingTermsOfService => 'Terms of Service';

  @override
  String get onboardingAgreeAnd => ' and ';

  @override
  String get onboardingPrivacyPolicy => 'Privacy Policy';

  @override
  String get registryPriorityLabel => 'Priority';

  @override
  String get registryPriorityLow => 'Nice to have';

  @override
  String get registryPriorityHigh => 'Really need this';

  @override
  String get registryDeleteItem => 'Delete Item';

  @override
  String get registryMarkPurchasedTitle => 'Mark as purchased?';

  @override
  String get registryMarkPurchased => 'Mark as purchased';

  @override
  String get registryAllCaughtUp => 'All caught up!';

  @override
  String get registryNothingPurchased => 'Nothing purchased yet.';

  @override
  String get shippingRemoveTitle => 'Remove shipping address?';

  @override
  String get shippingCountryLabel => 'Country';

  @override
  String get shippingSave => 'Save address';

  @override
  String get shippingRemove => 'Remove address';

  @override
  String get actionUndo => 'Undo';

  @override
  String get searchSelectBaby => 'Select a baby profile to search';

  @override
  String searchNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get actionOk => 'OK';

  @override
  String get babySwitcherEmpty => 'No baby profiles yet.';

  @override
  String get babySwitcherEditBaby => 'Edit baby';

  @override
  String get babySwitcherMyAccount => 'My Account';

  @override
  String get babySwitcherAddBaby => 'Add New Baby';
}
