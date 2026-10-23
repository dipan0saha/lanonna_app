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
  String get settingsSendTestCrash => 'Send test crash (Crashlytics)';

  @override
  String get settingsSendTestCrashSubtitle =>
      'Dev builds only. Verifies Firebase Crashlytics.';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsBiometricUnlock => 'Biometric sign-in & unlock';

  @override
  String get settingsBiometricUnlockSubtitle =>
      'Sign in with Face ID or fingerprint after logout, and lock the app when you return';

  @override
  String get authSignInWithBiometrics => 'Sign in with biometrics';

  @override
  String authSignInWithBiometricsAs(String name) {
    return 'Continue as $name';
  }

  @override
  String get biometricSignInReason => 'Sign in to La Nonna';

  @override
  String get biometricSignInFailed =>
      'Biometric sign-in did not work. Try again, or sign in with email or Google.';

  @override
  String get biometricSignInKeyInvalidated =>
      'Your fingerprints or face data changed on this device. Sign in with email or Google, then turn on biometric sign-in again in Settings.';

  @override
  String get biometricLockedOut =>
      'Too many attempts. Wait a moment, or sign in with email or Google.';

  @override
  String get settingsBiometricUnavailable =>
      'Biometrics are not available on this device.';

  @override
  String get settingsBiometricVerificationFailed =>
      'Biometric verification was cancelled or failed. Try again after enrolling a fingerprint or face unlock in device settings.';

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
      'This permanently deletes your La Nonna account and removes photos you uploaded to baby profiles owned by others. Any baby profiles solely owned by your account will also be deleted, including their photos, events, registry, and other data. Baby profiles with a co-owner will not be deleted; ownership will transfer fully to the co-owner.';

  @override
  String get deleteAccountButton => 'Delete my account';

  @override
  String get deleteAccountDeleting => 'Deleting…';

  @override
  String get deleteAccountChecking => 'Loading account details…';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account permanently?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently deletes your La Nonna account and removes photos you uploaded to baby profiles owned by others. Any baby profiles solely owned by your account will also be deleted, including their photos, events, registry, and other data. Baby profiles with a co-owner will not be deleted; ownership will transfer fully to the co-owner.';

  @override
  String get deleteAccountConfirmAction => 'Delete account';

  @override
  String get deleteAccountSoleOwnedHeading =>
      'These baby profiles will be deleted:';

  @override
  String deleteAccountSoleOwnedBaby(String name) {
    return '• $name';
  }

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
  String get memberSoleOwnerLeaveBody =>
      'You are the only owner. Add a co-owner and leave, delete the baby profile, or delete your account.';

  @override
  String get membershipEndedMessage =>
      'You no longer have access to this profile.';

  @override
  String get memberRemovedSuccess => 'Member removed.';

  @override
  String get inviteRevokeConfirmTitle => 'Revoke invitation?';

  @override
  String inviteRevokeConfirmBody(String email) {
    return '$email will no longer be able to join with this invite.';
  }

  @override
  String get memberLeftSuccess => 'You left this baby profile.';

  @override
  String get deleteBabyProfileAction => 'Delete baby profile';

  @override
  String get deleteBabyProfileConfirmTitle => 'Delete this baby profile?';

  @override
  String deleteBabyProfileConfirmBody(String babyName) {
    return 'This permanently deletes $babyName for everyone who follows this profile. All photos, calendar events, registry items, comments, and other data for this baby will be removed from La Nonna and cannot be recovered.';
  }

  @override
  String get deleteBabyProfileConfirmAction => 'Delete profile';

  @override
  String deleteBabyProfileFinalTitle(String babyName) {
    return 'Delete $babyName permanently?';
  }

  @override
  String get deleteBabyProfileFinalBody =>
      'Followers will lose access immediately. This cannot be undone.';

  @override
  String get deleteBabyProfileSuccess => 'Baby profile deleted.';

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
  String onboardingAgreeToTerms(String terms, String privacy) {
    return 'I agree to the $terms and $privacy';
  }

  @override
  String get onboardingTermsOfService => 'Terms of Service';

  @override
  String get onboardingPrivacyPolicy => 'Privacy Policy';

  @override
  String onboardingSignupAuthPrompt(String action) {
    return 'Already have an account? $action';
  }

  @override
  String onboardingLoginAuthPrompt(String action) {
    return 'Don\'t have an account? $action';
  }

  @override
  String get registryPriorityLabel => 'Priority';

  @override
  String get registryPriorityLow => 'Nice to have';

  @override
  String get registryPriorityHigh => 'Really need this';

  @override
  String get registryDeleteItem => 'Delete Item';

  @override
  String get registryDeleteConfirmTitle => 'Delete this item?';

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
  String get actionOk => 'OK';

  @override
  String get babySwitcherEmpty => 'No baby profiles yet.';

  @override
  String get babySwitcherEditBaby => 'Edit baby';

  @override
  String get babySwitcherMyAccount => 'My Account';

  @override
  String get babySwitcherAddBaby => 'Add New Baby';

  @override
  String get actionAdd2 => '+ Add';

  @override
  String get actionInviteMorePeople => '+ Invite more people';

  @override
  String get label123MainSt => '123 Main St';

  @override
  String get stage36Months => '3–6 months';

  @override
  String get stage612Months => '6–12 months';

  @override
  String get labelAccount => 'Account';

  @override
  String get actionAddBaby => 'Add Baby';

  @override
  String get actionAddEvent => 'Add Event';

  @override
  String get registryAddItemTitle => 'Add Item';

  @override
  String get actionAddPhoto => 'Add Photo';

  @override
  String get actionAddPhoto2 => 'Add a Photo';

  @override
  String get actionAddCalendarEvent => 'Add a calendar event';

  @override
  String get actionAddCaption => 'Add a caption…';

  @override
  String get actionAddName => 'Add a name...';

  @override
  String get actionAddRegistryItem => 'Add a registry item';

  @override
  String get actionAddShortDescription => 'Add a short description…';

  @override
  String get actionAddAddressKnows =>
      'Add an address so family knows where to send gifts.';

  @override
  String get actionAddAnother => 'Add another';

  @override
  String get actionAddBaby2 => 'Add baby';

  @override
  String get shellInviteRequiresOwnerBabyTitle => 'Add a baby profile first';

  @override
  String get shellInviteRequiresOwnerBabyMessage =>
      'Invites are sent from a baby profile you own. Create one, then invite family and friends.';

  @override
  String get registryAddItem => 'Add item';

  @override
  String get actionAddPhoto3 => 'Add photo';

  @override
  String get actionAddGallery => 'Add to gallery';

  @override
  String get actionAddFirstBabyProfile =>
      'Add your first baby profile to get started.';

  @override
  String get messageSuggestionsStage =>
      'All suggestions in this stage are on your calendar.';

  @override
  String get messageSuggestionsStage2 =>
      'All suggestions in this stage are on your registry.';

  @override
  String get hintSharePhoto => 'Also share this photo in the gallery';

  @override
  String get actionAnnounceArrival => 'Announce Arrival';

  @override
  String get actionAnnounceArrival2 => 'Announce arrival';

  @override
  String get announcementOnlyOwnersCanCreate =>
      'Only owners can create or edit the birth announcement.';

  String get announcementTitle => 'Announcement';

  @override
  String get fieldApt4b => 'Apt 4B';

  @override
  String get fieldAptSuiteEtcOptional => 'Apt, suite, etc. (optional)';

  @override
  String get labelBoyGirl => 'BOY OR GIRL?';

  @override
  String get labelBabyProfiles => 'Baby Profiles';

  @override
  String get labelBabyShower => 'Baby Shower';

  @override
  String get labelBabyName => 'Baby name';

  @override
  String get actionBack => 'Back';

  @override
  String get presetBaptism => 'Baptism';

  @override
  String get labelBirthdateGuesses => 'Birthdate guesses';

  @override
  String get presetBottles => 'Bottles';

  @override
  String get labelBoyGirl2 => 'Boy or Girl?';

  @override
  String get labelBoySNameOptional => 'Boy\'s name (optional)';

  @override
  String get announcementCommentsHeading => 'COMMENTS';

  @override
  String get fieldCity => 'City';

  @override
  String get actionClose => 'Close';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get fieldCountryOptional => 'Country (optional)';

  @override
  String get fieldCoverPhoto => 'Cover photo';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get actionCreateBabyProfileUse =>
      'Create a baby profile to use Gallery.';

  @override
  String get actionCreatePassword => 'Create a password';

  @override
  String get calendarCreateEvent => 'Create event';

  @override
  String get presetCribMattress => 'Crib & Mattress';

  @override
  String get fieldDate => 'Date';

  @override
  String get eventDeleteAction => 'Delete event';

  @override
  String get registryDeleteItemAction => 'Delete item';

  @override
  String get actionDeletePhoto => 'Delete photo';

  @override
  String get fieldDescriptionOptional => 'Description (optional)';

  @override
  String get eventDetailsHeading => 'Details';

  @override
  String get presetDiapers => 'Diapers';

  @override
  String get actionDownloadJsonCopy =>
      'Download a JSON copy of this baby\'s profile, members, photos and comments, calendar and RSVPs, registry and purchases, name ideas, predictions, the birth announcement, and recent activity.';

  @override
  String get presetDueDate => 'Due Date';

  @override
  String get actionEditBaby => 'Edit Baby';

  @override
  String get actionEditProfile => 'Edit Profile';

  @override
  String get actionEditAnnouncement => 'Edit announcement';

  @override
  String get actionEditCaption => 'Edit caption';

  @override
  String get eventEditAction => 'Edit event';

  @override
  String get registryEditItem => 'Edit item';

  @override
  String get labelEmailPhone => 'Email or phone';

  @override
  String get hintEnterPassword => 'Enter your password';

  @override
  String get eventTitle => 'Event';

  @override
  String get fieldEventTitle => 'Event Title';

  @override
  String get searchSectionEvents => 'Events';

  @override
  String get stageExpecting => 'Expecting';

  @override
  String get messageFun => 'Family Fun';

  @override
  String get messageInsight => 'Family Insight';

  @override
  String get messageItem =>
      'Family will see this item as taken so no one buys it again.';

  @override
  String get presetFirstCheckup => 'First Checkup';

  @override
  String get presetFirstHolidays => 'First Holidays';

  @override
  String get fieldFirstName => 'First name';

  @override
  String get messageFollowersLonger =>
      'Followers will no longer see where to send gifts.';

  @override
  String get navFun => 'Fun';

  @override
  String get labelGenderReveal => 'Gender Reveal';

  @override
  String get labelGettingStarted => 'Getting Started';

  @override
  String get labelGirlSNameOptional => 'Girl\'s name (optional)';

  @override
  String get actionGoHome => 'Go to Home';

  @override
  String get brandGoogle => 'Google';

  @override
  String get navHome => 'Home';

  @override
  String get labelIl => 'IL';

  @override
  String get labelPhoto => 'IN THIS PHOTO';

  @override
  String get actionInvite => 'Invite';

  @override
  String get actionInviteFriends => 'Invite Family & Friends';

  @override
  String get actionInviteStatus => 'Invite Status';

  @override
  String get actionInviteMorePeople2 => 'Invite more people';

  @override
  String get fieldItemName => 'Item Name';

  @override
  String get fieldLastName => 'Last name';

  @override
  String get announcementLengthLabel => 'Length';

  @override
  String get fieldLinkOptional => 'Link (optional)';

  @override
  String get fieldLocationOptional => 'Location (optional)';

  @override
  String get authLogIn => 'Log in';

  @override
  String get labelMyAccount => 'My account';

  @override
  String get labelName => 'Name';

  @override
  String get searchSectionNames => 'Names';

  @override
  String get registrySectionNeeded => 'Needed';

  @override
  String get labelNewFollowers => 'New Followers';

  @override
  String get stageNewborn03mo => 'Newborn (0–3mo)';

  @override
  String get actionNextUp => 'Next Up';

  @override
  String get actionNextMonth => 'Next month';

  @override
  String get actionNextPhoto => 'Next photo';

  @override
  String get emptyAnnouncementYet => 'No announcement yet';

  @override
  String get emptyEventsDay => 'No events this day.';

  @override
  String get emptyEventsYet => 'No events yet';

  @override
  String get emptyVotesYetCheckBack =>
      'No family votes yet. Check back once everyone starts playing along in Fun.';

  @override
  String get emptyFavoritesYet => 'No favorites yet';

  @override
  String get emptyFurtherUpcomingEvents => 'No further upcoming events';

  @override
  String get emptyNameSuggestionsYet => 'No name suggestions yet';

  @override
  String get emptyPhotosLast30 =>
      'No photos in the last 30 days. Upload a new moment or browse the full gallery.';

  @override
  String get emptyPhotosYet => 'No photos yet';

  @override
  String get emptyRecentPhotos => 'No recent photos';

  @override
  String get registryEmptyTitle => 'No registry items yet';

  @override
  String get calendarNoUpcomingEvents => 'No upcoming events';

  @override
  String get emptyVotesYetInvite =>
      'No votes yet. Invite family so they can guess names, gender, and the big day.';

  @override
  String get hintSureStart =>
      'Not sure where to start? See AI-suggested events by stage and age.';

  @override
  String get hintSureStart2 =>
      'Not sure where to start? See AI-suggested items by stage and age.';

  @override
  String get hintWasMeant => 'Not who this was meant for?';

  @override
  String get notificationPrefsChannelsTitle => 'Notification channels';

  @override
  String get notificationPrefsTitle => 'Notification preferences';

  @override
  String get labelNotificationsProfileHelp =>
      'Notifications, profile, and help';

  @override
  String get hintDefaultFollowers =>
      'Off by default. Followers only see gallery photos you choose to share.';

  @override
  String get presetOnesies => 'Onesies';

  @override
  String get actionOpenPhoto => 'Open photo';

  @override
  String get labelPrivateOrganizedConnected => 'PRIVATE. ORGANIZED. CONNECTED.';

  @override
  String get fieldPassword => 'Password';

  @override
  String get hintPasteZoomFacetimeLink => 'Paste a Zoom / FaceTime link';

  @override
  String get hintPasteLinkItem => 'Paste a link to the item';

  @override
  String get labelPendingInvites => 'Pending invites';

  @override
  String get fieldPhoneNumberOptional => 'Phone number (optional)';

  @override
  String get searchSectionPhotos => 'Photos';

  @override
  String get labelPopularDates => 'Popular Dates';

  @override
  String get labelPreferences => 'Preferences';

  @override
  String get actionPreviousMonth => 'Previous month';

  @override
  String get actionPreviousPhoto => 'Previous photo';

  @override
  String get registrySectionPurchased => 'Purchased';

  @override
  String get labelQuickActions => 'Quick Actions';

  @override
  String get eventRsvpsTitle => 'RSVPs';

  @override
  String get labelRecentActivity => 'Recent Activity';

  @override
  String get labelRecentPhotos => 'Recent Photos';

  @override
  String get onboardingRemoveInvite => 'Remove invite';

  @override
  String get actionResendInvitation => 'Resend invitation';

  @override
  String get actionRevokeInvitation => 'Revoke invitation';

  @override
  String get fieldSelectCountry => 'Select a country';

  @override
  String get fieldSelectDate => 'Select a date';

  @override
  String get fieldSelectTime => 'Select a time';

  @override
  String get actionSendInvites => 'Send Invites';

  @override
  String get actionShareKeepsakeCardPhoto =>
      'Share a keepsake card with photo and birth details for family.';

  @override
  String get actionShareAnnouncement => 'Share announcement';

  @override
  String get actionShareAnnouncementInstagram =>
      'Share announcement to Instagram';

  @override
  String get actionShareNews =>
      'Share the news with family. They will see a keepsake card with photo and details.';

  @override
  String get messageSharedAcrossEveryBabyProfile =>
      'Shared across every baby profile you own. Free tier includes 15 GB.';

  @override
  String get shippingAddressTitle => 'Shipping address';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get actionSkipNow => 'Skip for now';

  @override
  String get labelSpringfield => 'Springfield';

  @override
  String get messageSquishPhotosLove =>
      'Squish photos you love and they will show up here.';

  @override
  String get hintStandardSizeGreenguardGoldCertified =>
      'Standard size, GREENGUARD Gold certified…';

  @override
  String get fieldStateProvinceOptional => 'State / Province (optional)';

  @override
  String get labelStorage => 'Storage';

  @override
  String get fieldStreetAddress => 'Street address';

  @override
  String get labelSuggestName => 'Suggest a name';

  @override
  String get labelSuggestName2 => 'Suggest a name…';

  @override
  String get presetSwaddles => 'Swaddles';

  @override
  String get actionSwitchBabyProfile => 'Switch baby profile';

  @override
  String get babySwitcherSwitchProfile => 'Switch profile';

  @override
  String get labelTopGuessDate => 'TOP GUESS DATE';

  @override
  String get labelTopName => 'TOP NAME';

  @override
  String get messageRemoves =>
      'This removes it for everyone who can see it - this can\'t be undone.';

  @override
  String get messageStartTime =>
      'This start time is in the past. The event still appears on the month grid and under Today on Calendar, but not in Upcoming.';

  @override
  String get fieldTimeOptional => 'Time (optional)';

  @override
  String get labelToday => 'Today';

  @override
  String get registryUndoPurchase => 'Undo purchase';

  @override
  String get labelUpcoming => 'Upcoming';

  @override
  String get labelUpcomingEvents => 'Upcoming Events';

  @override
  String get versionGateUpdateRequired => 'Update required';

  @override
  String get actionUploadFirstPhoto => 'Upload your first photo';

  @override
  String get messageVerificationCompleteTapContinueProceed =>
      'Verification complete. Tap Continue to proceed.';

  @override
  String get eventVideoCallLabel => 'Video Call';

  @override
  String get fieldVideoCallLinkOptional => 'Video call link (optional)';

  @override
  String get actionViewGallery => 'View Gallery';

  @override
  String get actionViewRsvps => 'View RSVPs ›';

  @override
  String get actionView => 'View all';

  @override
  String get actionViewAnnouncement => 'View announcement';

  @override
  String get actionVoteFun => 'Vote in Fun';

  @override
  String get announcementWeightLabel => 'Weight';

  @override
  String get hintShouldSendRegistryGifts =>
      'Where should family send registry gifts?';

  @override
  String get labelVoted => 'Who voted';

  @override
  String get messageChangeTime => 'You can change this any time.';

  @override
  String get messageSuggestName => 'You can suggest 1 name per gender.';

  @override
  String get messageReOfficiallyOwner => 'You\'re officially an Owner!';

  @override
  String get messageReOfflineCheckConnection =>
      'You\'re offline. Check your connection.';

  @override
  String get messageVeReachedEnd => 'You\'ve reached the end of the gallery.';

  @override
  String get fieldZipPostalCode => 'Zip / Postal code';

  @override
  String get fieldZipPostalCodeOptional => 'Zip / Postal code (optional)';

  @override
  String get labelEG94103 => 'e.g. 94103';

  @override
  String get labelEGCribMattress => 'e.g. Crib & Mattress';

  @override
  String get labelEGGenderRevealParty => 'e.g. Gender Reveal Party';

  @override
  String get labelEGGrandmaSueSBackyard => 'e.g. Grandma Sue\'s backyard';

  @override
  String get labelEGLiam => 'e.g. Liam';

  @override
  String get labelEGOlivia => 'e.g. Olivia';

  @override
  String get labelSignEmail => 'or sign in with email';

  @override
  String get labelSignUpEmail => 'or sign up with email';

  @override
  String get messageEmailCom => 'you@email.com';

  @override
  String get messagePerson =>
      '👑 This person will also be a Baby Profile Owner';

  @override
  String get commentDeleteMenuLabel => 'Delete comment';

  @override
  String versionGateUnsupported(
    String installedVersion,
    String minimumVersion,
  ) {
    return 'This version ($installedVersion) is no longer supported. Install $minimumVersion or newer to continue.';
  }

  @override
  String chipRemoveSemantics(String label) {
    return 'Remove $label';
  }

  @override
  String registryPriorityShort(int priority) {
    return 'P$priority';
  }

  @override
  String notificationPrefsFrequencyTitle(String babyLabel) {
    return 'How often would you like updates for $babyLabel?';
  }

  @override
  String accountStorageUsed(String used, String quota) {
    return '$used of $quota used';
  }

  @override
  String funRemoveNameSemantics(String name) {
    return 'Remove $name';
  }

  @override
  String predictionYourGenderVote(String vote) {
    return 'Your vote: $vote';
  }

  @override
  String photoUploadedBy(String meta, String name) {
    return 'Uploaded $meta by $name';
  }

  @override
  String photoTaggedBabies(String names) {
    return 'In this photo: $names';
  }

  @override
  String homeBirthWelcomeTitle(String name) {
    return '$name is here!';
  }

  @override
  String homeWaitingFor(String name) {
    return 'Waiting for $name';
  }

  @override
  String inviteCoOwnerAccessBody(String babyName, String inviterName) {
    return 'You now have full access to edit $babyName\'\'s profile, add events, manage the registry, and invite others, just like $inviterName.';
  }

  @override
  String get emailVerifyDevAddressHint =>
      'This looks like a dev-only address - it may not receive mail. Mark the account verified in Firebase Console, or use a real email.';

  @override
  String registryPurchasedBy(String name) {
    return 'Purchased by $name';
  }

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String get lifecycleBorn => 'Born';

  @override
  String get genderBoy => 'Boy';

  @override
  String get genderGirl => 'Girl';

  @override
  String get genderNotSure => 'Not sure yet';

  @override
  String get exportStatusPending => 'Queued';

  @override
  String get exportStatusRunning => 'Preparing';

  @override
  String get exportStatusReady => 'Ready';

  @override
  String get exportStatusFailed => 'Failed';

  @override
  String get digestRealtime => 'Real-time';

  @override
  String get digestDaily => 'Daily digest';

  @override
  String get digestWeekly => 'Weekly digest';

  @override
  String get digestSummaryRealtime => 'Real-time updates';

  @override
  String get digestSummaryDaily => 'Daily email summary';

  @override
  String get digestSummaryWeekly => 'Weekly email summary';

  @override
  String get invitationStatusPending => 'Pending';

  @override
  String get invitationStatusAccepted => 'Accepted';

  @override
  String get invitationStatusExpired => 'Expired';

  @override
  String get invitationStatusRevoked => 'Revoked';

  @override
  String get inviteEmailPending => 'Pending — email sending';

  @override
  String get inviteEmailSent => 'Invite email sent';

  @override
  String get inviteEmailFailed => 'Email failed to send';

  @override
  String settingsCouldNotOpenEmailTo(String supportEmail) {
    return 'Could not open email to $supportEmail. Copy link?';
  }

  @override
  String get homeConfirmTheDateOfBirth =>
      'Confirm the date of birth. Your home will update to celebrate your baby.';

  @override
  String get homeDateOfBirthCannotBe =>
      'Date of birth cannot be in the future.';

  @override
  String homeYoullBeNotifiedTheMoment(String babyName) {
    return 'You\'ll be notified the moment $babyName arrives.';
  }

  @override
  String get homeViewAnnouncement => '🎀 View Announcement';

  @override
  String get homeShareToInstagram => '📸 Share to Instagram';

  @override
  String get homeEveryoneYouveInvitedHasBeen =>
      'Everyone you\'ve invited has been notified.';

  @override
  String homeDaysToDueDate(String dueDateLabel) {
    return 'Days to due date · $dueDateLabel';
  }

  @override
  String get homeDaysToDueDateHeading => 'DAYS TO DUE DATE';

  @override
  String homeCouldNotUpdateBaby(String reason) {
    return 'Could not update baby: $reason';
  }

  @override
  String get calendarOnlyOwnersCanCreateOr =>
      'Only owners can create or edit calendar events.';

  @override
  String get calendarBabyProfileIsStillLoading =>
      'Baby profile is still loading. Try again.';

  @override
  String get calendarEnterAnEventTitleTo => 'Enter an event title to continue.';

  @override
  String get calendarSaveChanges => 'Save Changes';

  @override
  String get calendarSaveEvent => 'Save Event';

  @override
  String get calendarEditEvent => 'Edit Event';

  @override
  String get calendarNewEvent => 'New Event';

  @override
  String get calendarAddUltrasoundsShowersOrThe =>
      'Add ultrasounds, showers, or the gender reveal so family knows when to celebrate.';

  @override
  String get calendarNothingOnTheCalendarYet =>
      'Nothing on the calendar yet — check back soon.';

  @override
  String get calendarAddEventCta => '+ Add Event';

  @override
  String get calendarCouldNotLoadEventsPull =>
      'Could not load events. Pull to refresh or try again.';

  @override
  String get calendarWhen => 'When';

  @override
  String get calendarLocation => 'Location';

  @override
  String get calendarYourRsvp => 'Your RSVP';

  @override
  String get calendarComments => 'Comments';

  @override
  String suggestionsLoadFailed(String reason) {
    return 'Could not load suggestions: $reason';
  }

  @override
  String get calendarEventAddedToCalendar => 'Event added to calendar';

  @override
  String get calendarPhotoOptional => 'Photo (optional)';

  @override
  String get shellYoureTheOwnerOfOne =>
      'You\'re the Owner of one and a Follower of another.';

  @override
  String get shellChooseWhichBabyProfileTo =>
      'Choose which baby profile to view.';

  @override
  String get galleryFavorites => 'Favorites';

  @override
  String get galleryAllPhotos => 'All photos';

  @override
  String get galleryRecentActivity => 'Recent activity';

  @override
  String get galleryPhotoUploaded => 'Photo uploaded';

  @override
  String galleryUploadFailed(String reason) {
    return 'Upload failed: $reason';
  }

  @override
  String get galleryPhotoProcessingIsTakingLonger =>
      'Photo processing is taking longer than usual. Pull to refresh the gallery.';

  @override
  String get galleryThisPhotoIsNoLonger => 'This photo is no longer available.';

  @override
  String get galleryNoCaption => 'No caption';

  @override
  String galleryAddYourFirstPhotoTo(String name) {
    return 'Add your first photo to start sharing $name\'s journey with family.';
  }

  @override
  String get galleryOnceAPhotoIsShared =>
      'Once a photo is shared, it will show up here for everyone to enjoy.';

  @override
  String get galleryAddPhoto => '+ Add Photo';

  @override
  String get funPredictions => 'Predictions';

  @override
  String get funNoVotesYet => 'No votes yet';

  @override
  String get funNoGuessesYet => 'No guesses yet';

  @override
  String get funNoGuessesYetBeThe => 'No guesses yet - be the first!';

  @override
  String get funNoNameIdeasWereSaved =>
      'No name ideas were saved before baby arrived.';

  @override
  String get funSuggestANameBelowEveryone =>
      'Suggest a name below — everyone gets a say.';

  @override
  String get funBoys => 'Boys';

  @override
  String get funGirls => 'Girls';

  @override
  String funUnlike(String suggestedName) {
    return 'Unlike $suggestedName';
  }

  @override
  String funLove(String suggestedName) {
    return 'Love $suggestedName';
  }

  @override
  String get registryOnlyOwnersCanEditThe =>
      'Only owners can edit the shipping address.';

  @override
  String registryCouldNotLoadShippingAddress(String e) {
    return 'Could not load shipping address: $e';
  }

  @override
  String get registryEditRegistryItem => 'Edit Registry Item';

  @override
  String get registryAddRegistryItem => 'Add Registry Item';

  @override
  String get registryIllBuyThis => 'I\'ll buy this';

  @override
  String get registryAddTheThingsYourBaby =>
      'Add the things your baby will need so family knows what to bring.';

  @override
  String get registryNothingsBeenAddedToThe =>
      'Nothing\'s been added to the registry yet — check back soon.';

  @override
  String get registryAddItemCta => '+ Add Item';

  @override
  String get babyBabyCreated => 'Baby created';

  @override
  String get babyBabyUpdated => 'Baby updated';

  @override
  String babyProfilePhotoFailed(String createdLabel, String reason) {
    return '$createdLabel; profile photo failed: $reason';
  }

  @override
  String get babyProfilePhotoSavedGalleryUpload =>
      'Profile photo saved; gallery upload failed';

  @override
  String babyGalleryUploadFailed(String createdLabel) {
    return '$createdLabel; gallery upload failed';
  }

  @override
  String get babyExpectedDueDate => 'Expected Due Date';

  @override
  String get babyCreateBaby => 'Create Baby';

  @override
  String get babyExpectedDueDateCannotBe =>
      'Expected due date cannot be in the past.';

  @override
  String get babyProfilePhotoOptional => 'Profile photo (optional)';

  @override
  String get babyUpdateYourBabysProfile => 'Update your baby\'s profile';

  @override
  String get babyCreateYourBabysProfile => 'Create your baby\'s profile';

  @override
  String get babyYouCanAlwaysAddOr =>
      'You can always add or change these details later.';

  @override
  String get babyAlreadyBorn => 'Already Born';

  @override
  String get babyGender => 'Gender';

  @override
  String get babyTapContinueToTryAgain => 'Tap Continue to try again.';

  @override
  String get babyTapCreateBabyToTry => 'Tap Create Baby to try again.';

  @override
  String get accountShowPassword => 'Show password';

  @override
  String get accountHidePassword => 'Hide password';

  @override
  String get accountNoBabyProfileYouOwn => 'No baby profile you own yet.';

  @override
  String get accountExpectedDueDate => 'Expected due date';

  @override
  String get accountTapToChoose => 'Tap to choose';

  @override
  String get accountCouldntOpenTheDownloadCopy =>
      'Couldn\'t open the download. Copy link?';

  @override
  String get accountRequesting => 'Requesting…';

  @override
  String get accountRequestNewExport => 'Request new export';

  @override
  String get accountPhotosSquished => 'Photos Squished';

  @override
  String get accountEventsAttended => 'Events Attended';

  @override
  String get accountItemsBought => 'Items Bought';

  @override
  String get accountPendingInvite => 'Pending invite';

  @override
  String accountAccepted(String formatted) {
    return 'Accepted · $formatted';
  }

  @override
  String get accountInviteEmailQueued => 'Invite email queued';

  @override
  String get announcementFamily => 'Family';

  @override
  String get announcementOptional => 'Optional';

  @override
  String get announcementSaveAnnouncement => 'Save Announcement';

  @override
  String get announcementOurBabyAnnouncementIsHere =>
      'Our baby announcement is here!';

  @override
  String announcementMeet(String name) {
    return 'Meet $name!';
  }

  @override
  String get announcementBabyAnnouncement => 'Baby announcement';

  @override
  String get onboardingWeCouldntLoadYourBaby =>
      'We couldn\'t load your baby profile. Check your connection and try again.';

  @override
  String get onboardingAtLeast6CharactersWith =>
      'At least 6 characters, with a number or symbol.';

  @override
  String get onboardingWePulledInYourDetails =>
      'We pulled in your details. Add a photo so family knows who\'s who.';

  @override
  String get onboardingCompleteYourProfile => 'Complete your profile';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingCouldNotSendVerificationEmail =>
      'Could not send verification email. Please try again.';

  @override
  String get onboardingYourEmail => 'your email';

  @override
  String get onboardingTheOwner => 'The owner';

  @override
  String onboardingWelcomeToSCircle(String babyName) {
    return 'Welcome to $babyName\'s circle';
  }

  @override
  String onboardingAddedYouAs(String inviter) {
    return '$inviter added you as';
  }

  @override
  String onboardingThisIsHowYoullAppear(String inviter) {
    return 'This is how you\'ll appear to the rest of the family. $inviter can update it anytime from their side.';
  }

  @override
  String get onboardingOpen => 'Open';

  @override
  String get onboardingAcceptInvitation => 'Accept Invitation';

  @override
  String get onboardingReliveEveryMilestoneInThe =>
      'Relive every milestone in the Gallery';

  @override
  String get onboardingBabyIsAlreadyHereSee =>
      'Baby is already here. See the first photos and everything since.';

  @override
  String get onboardingVoteGuessInFamilyFun => 'Vote & guess in Family Fun';

  @override
  String get onboardingSuggestNamesVoteOnFavorites =>
      'Suggest names, vote on favorites, and guess the birthdate. Results reveal once baby arrives.';

  @override
  String get onboardingWelcomeYoureIn => 'Welcome, you\'re in!';

  @override
  String get onboardingAPrivateSpaceJustFor =>
      'A private space just for the family and friends closest to your circle.';

  @override
  String get onboardingSquishPhotosLeaveComments =>
      'Squish photos & leave comments';

  @override
  String get onboardingTapTheHeartToSquish =>
      'Tap the heart to \"squish\" any photo the family shares.';

  @override
  String get onboardingNeverMissWhatsNext => 'Never miss what\'s next';

  @override
  String get onboardingSeeUpcomingEventsLikeGender =>
      'See upcoming events, like gender reveals and baby showers, and RSVP right from the app.';

  @override
  String get onboardingGetUpdatesYourWay => 'Get updates your way';

  @override
  String get onboardingChooseHowOftenYouHear =>
      'Choose how often you hear from us: real-time, daily, or a weekly digest. You can change this anytime.';

  @override
  String get onboardingFollowerGetStarted => 'Get Started';

  @override
  String get onboardingAcceptJoinAsOwner => 'Accept & Join as Owner';

  @override
  String get onboardingYourCoParent => 'your co-parent';

  @override
  String get onboardingSignInToAcceptYour =>
      'Sign in to accept your invitation and continue.';

  @override
  String get onboardingSignInToContinueSetting =>
      'Sign in to continue setting up your family space.';

  @override
  String get onboardingGoogleSignInIsNot =>
      'Google Sign-In is not configured for this Android build yet. Use email/password, or enable Google in Firebase for lanonna-dev.';

  @override
  String get onboardingWelcomeBack => 'Welcome back';

  @override
  String get onboardingAiSuggestedByStageAnd => 'AI-suggested by stage and age';

  @override
  String get onboardingAddYourFirstMoment => 'Add your first moment';

  @override
  String get onboardingTotallyOptionalButItHelps =>
      'Totally optional, but it helps family feel like there\'s already something here.';

  @override
  String get onboardingSeedsTheVoteInFamily => 'Seeds the vote in Family Fun';

  @override
  String get onboardingFromYourCameraOrLibrary => 'From your camera or library';

  @override
  String get onboardingYourRelationshipToBaby => 'Your relationship to baby';

  @override
  String get invitationsAlreadyOnTheFamily => 'Already on the family';

  @override
  String get invitationsInvitationAlreadyPending =>
      'Invitation already pending';

  @override
  String get invitationsAddAnotherPerson => 'Add another person';

  @override
  String get invitationsInviteFamilyFriends => 'Invite family & friends';

  @override
  String get invitationsAddThePeopleYouWant =>
      'Add the people you want to share this with. You can always invite more later.';

  @override
  String get invitationsWellSendEachPersonA =>
      'We\'ll send each person a private link. It expires in 14 days.';

  @override
  String get invitationsAFamilyMember => 'A family member';

  @override
  String get invitationsYoureAlreadyAMember => 'You\'re already a member';

  @override
  String get invitationsAsACoOwnerYoull =>
      'As a co-owner, you\'ll have full access to edit, invite, and manage, just like the person who invited you.';

  @override
  String get invitationsAPrivateSpaceJustFor =>
      'A private space just for family & friends. Nothing here is public.';

  @override
  String get invitationsInvitationUnavailable => 'Invitation unavailable';

  @override
  String homeInvitesNotifiedWithLine(String line) {
    return '$line. Everyone you\'ve invited has been notified.';
  }

  @override
  String invitationsInvitedYouToCoOwn(String inviter) {
    return '$inviter invited you to co-own';
  }

  @override
  String invitationsInvitedYouToFollow(String inviter) {
    return '$inviter invited you to follow';
  }

  @override
  String eventRsvpGoingCount(int count) {
    return '$count going';
  }

  @override
  String eventRsvpMaybeCount(int count) {
    return '$count maybe';
  }

  @override
  String get errorAccountDeleted => 'This account was deleted.';

  @override
  String get errorOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorNetwork =>
      'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorServiceUnavailable =>
      'The service is busy right now. Please try again in a moment.';

  @override
  String get errorInvalidRequest =>
      'Some details aren\'t valid. Check them and try again.';

  @override
  String get errorNotFound => 'This item is no longer available.';

  @override
  String get errorForbidden => 'You don\'t have permission to do that.';

  @override
  String get errorConflict =>
      'This changed while you were working. Refresh and try again.';

  @override
  String get errorUnauthenticated =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorAppCheckFailed =>
      'This app couldn\'t be verified. Update the app and try again.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get errorNotMember => 'You\'re not a member of this baby profile.';

  @override
  String get errorTargetNotMember =>
      'That person is no longer a member of this baby profile.';

  @override
  String get errorLastOwner =>
      'You can\'t remove the last owner of this baby profile.';

  @override
  String get errorCannotDeleteSharedBaby =>
      'This baby profile has a co-owner. Leave the profile instead of deleting it.';

  @override
  String get errorUseLeaveProfile => 'To remove yourself, use Leave profile.';

  @override
  String get errorEmailNotVerified =>
      'Verify your email before finishing setup.';

  @override
  String get errorBabyProfileRequired =>
      'Create a baby profile before finishing setup.';

  @override
  String get errorProfileIncomplete =>
      'Complete your profile before finishing setup.';

  @override
  String get errorInvalidBirthDate => 'Enter a valid date of birth.';

  @override
  String errorTextTooLong(int maxLength) {
    return 'Keep this to $maxLength characters or fewer.';
  }

  @override
  String get errorInvalidBirthTime =>
      'Enter the birth time as HH:MM (24-hour).';

  @override
  String get errorCommentRequired => 'Write a comment first.';

  @override
  String get errorUnsupportedMediaType => 'This file type isn\'t supported.';

  @override
  String get errorFileTooLarge => 'This file is too large.';

  @override
  String get errorFunClosed => 'Fun is closed — baby has arrived!';

  @override
  String get errorPredictionsClosed =>
      'Predictions are closed — baby has arrived!';

  @override
  String get errorDuplicateNameSuggestion =>
      'That name is already on the list.';

  @override
  String get errorNameAlreadySuggested =>
      'You\'ve already suggested a name for this gender.';

  @override
  String get errorAlreadyOnRegistry => 'This is already on the registry.';

  @override
  String get errorRegistryItemPurchased =>
      'This gift has already been purchased.';

  @override
  String get errorShippingAddressIncomplete =>
      'Add the street address, city, postal code and country.';

  @override
  String get errorAlreadyOnCalendar => 'This is already on the calendar.';

  @override
  String get errorEventEndBeforeStart =>
      'The end time must be at or after the start time.';

  @override
  String get errorBiometricCredentialInvalid =>
      'Biometric sign-in is no longer set up on this device. Sign in with email or Google, then turn it on again in Settings.';

  @override
  String get errorBiometricChallengeExpired =>
      'Biometric sign-in timed out. Try again.';

  @override
  String get errorEmailQueueFailed =>
      'The invite was saved, but its email couldn\'t be sent. Use Resend on Manage followers.';

  @override
  String get errorExportQueueFailed =>
      'The export couldn\'t be started. Please try again in a few minutes.';

  @override
  String errorPhotoTooLarge(String megabytes) {
    return 'Photo exceeds the maximum size ($megabytes MB).';
  }

  @override
  String photoSourceHint(String megabytes) {
    return 'JPEG or PNG, up to ${megabytes}MB';
  }

  @override
  String get inviteErrorExpired =>
      'This invitation has expired. Ask the family to send a new invite.';

  @override
  String get inviteErrorRevoked =>
      'This invitation was revoked. Ask the family to send a new invite.';

  @override
  String get inviteErrorAlreadyUsed =>
      'This invitation was already used. Sign in with the account that accepted it.';

  @override
  String get inviteErrorNotFound =>
      'This invitation link is invalid or was revoked.';

  @override
  String get inviteErrorMaxOwners =>
      'This baby already has the maximum number of owners.';

  @override
  String get inviteErrorEmailMismatch =>
      'Sign in with the email address that received the invitation.';

  @override
  String get inviteErrorGeneric =>
      'Could not accept this invitation. Please try again.';

  @override
  String get inviteErrorOffline =>
      'Connect to the internet to open this invitation.';

  @override
  String get inviteErrorLoadFailed =>
      'Could not load this invitation. Try again.';

  @override
  String get validationEmailRequired => 'Email is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email';

  @override
  String get validationPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get validationPasswordNeedsSymbol => 'Include a number or symbol';

  @override
  String get validationDisplayNameRequired => 'Display name is required';

  @override
  String get validationDisplayNameTooLong => 'Display name is too long';

  @override
  String get validationFirstNameRequired => 'First name is required';

  @override
  String get validationLastNameRequired => 'Last name is required';

  @override
  String get validationPhoneInvalid => 'Enter a valid phone number';

  @override
  String get validationTermsRequired => 'Please accept the terms to continue';

  @override
  String get validationRelationshipRequired =>
      'Select your relationship to baby';

  @override
  String get validationNameRequired => 'Name is required';

  @override
  String get validationItemNameRequired => 'Item name is required';

  @override
  String get validationStreetRequired => 'Street address is required';

  @override
  String get validationCityRequired => 'City is required';

  @override
  String get validationPostalCodeRequired => 'Zip / Postal code is required';

  @override
  String get validationCountryRequired => 'Select a country';

  @override
  String get validationUrlInvalid => 'Enter a valid link, e.g. https://…';

  @override
  String get authErrorTooManyAttempts =>
      'Too many attempts. Wait a few minutes, then try Resend email again.';

  @override
  String get authErrorVerifyLinkExpired =>
      'This verification link has expired or was already used. Tap Resend email for a new link.';

  @override
  String get authErrorVerifyLinkFailed =>
      'Could not verify your email from this link. Try Resend email or open the newest message in your inbox.';

  @override
  String get linkOpenFailedCopy => 'Couldn\'t open the link. Copy link?';

  @override
  String get linkCopyAction => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get storeOpenFailedCopy => 'Couldn\'t open the store. Copy link?';

  @override
  String get inviteBabyAlreadyHere => 'Already here';

  @override
  String get inviteBabyOnTheWay => 'On the way';

  @override
  String inviteBabyArriving(String date) {
    return 'Arriving $date';
  }

  @override
  String lifecycleBornOn(String date) {
    return 'Born $date';
  }

  @override
  String lifecycleDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get ownerCarouselTitle1 => 'Your baby\'s story, in one private place';

  @override
  String get ownerCarouselBody1 =>
      'Photos, updates, and everything in between, visible only to the people you invite.';

  @override
  String get ownerCarouselTitle2 => 'Everyone gets to feel close';

  @override
  String get ownerCarouselBody2 =>
      'Grandparents, aunts, uncles, and friends can follow along, no matter how far away they live.';

  @override
  String get ownerCarouselTitle3 => 'Celebrate every milestone together';

  @override
  String get ownerCarouselBody3 =>
      'Calendar events, a shared registry, and fun ways to mark the big days.';

  @override
  String get ownerCarouselTitle4 => 'Never lose a moment';

  @override
  String get ownerCarouselBody4 =>
      'Every photo and comment, saved in one safe place, for good.';

  @override
  String get relativeTimeJustNow => 'Just now';

  @override
  String get relativeTimeYesterday => 'Yesterday';

  @override
  String relativeTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get calendarWeekdaySun => 'Su';

  @override
  String get calendarWeekdayMon => 'Mo';

  @override
  String get calendarWeekdayTue => 'Tu';

  @override
  String get calendarWeekdayWed => 'We';

  @override
  String get calendarWeekdayThu => 'Th';

  @override
  String get calendarWeekdayFri => 'Fr';

  @override
  String get calendarWeekdaySat => 'Sa';

  @override
  String get onboardingCompleteProfileSubtext =>
      'Add your name and photo so family knows who\'s who.';

  @override
  String get activityEmptyDefault =>
      'Nothing yet - activity will show up here.';

  @override
  String get photoAddAction => 'Add a photo';

  @override
  String get photoChangeAction => 'Change photo';

  @override
  String get photoUploadingLabel => 'Uploading photo…';

  @override
  String get babyNameDefault => 'Baby';

  @override
  String get personNameFallback => 'Family member';

  @override
  String get relationshipWife => 'Wife';

  @override
  String get relationshipHusband => 'Husband';

  @override
  String get relationshipMother => 'Mother';

  @override
  String get relationshipFather => 'Father';

  @override
  String get relationshipGrandma => 'Grandma';

  @override
  String get relationshipGrandpa => 'Grandpa';

  @override
  String get relationshipAunt => 'Aunt';

  @override
  String get relationshipUncle => 'Uncle';

  @override
  String get relationshipGodmother => 'Godmother';

  @override
  String get relationshipGodfather => 'Godfather';

  @override
  String get relationshipFamilyFriend => 'Family Friend';

  @override
  String activityPhotoShared(String actor) {
    return '$actor shared a photo';
  }

  @override
  String activityPhotoSharedCaption(String actor, String caption) {
    return '$actor shared \"$caption\"';
  }

  @override
  String activityPhotoSquish(String actor) {
    return '$actor squished a photo';
  }

  @override
  String activityPhotoSquishCaption(String actor, String caption) {
    return '$actor squished \"$caption\"';
  }

  @override
  String activityPhotoComment(String actor) {
    return '$actor commented on a photo';
  }

  @override
  String activityPhotoCommentCaption(String actor, String caption) {
    return '$actor commented on \"$caption\"';
  }

  @override
  String activityRegistryItemAdded(String actor, String item) {
    return '$actor added \"$item\" to the registry';
  }

  @override
  String activityRegistryPurchased(String actor, String item) {
    return '$actor marked \"$item\" as purchased';
  }

  @override
  String activityRegistryClaimed(String item) {
    return 'Someone is buying \"$item\"';
  }

  @override
  String activityEventCreated(String actor, String title) {
    return '$actor added \"$title\" to the calendar';
  }

  @override
  String activityNameSuggested(String actor, String name) {
    return '$actor suggested the name \"$name\"';
  }

  @override
  String activityGenderVoteCast(String actor, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': '$actor guessed boy',
      'female': '$actor guessed girl',
      'other': '$actor made a gender guess',
    });
    return '$_temp0';
  }

  @override
  String activityBabyArrived(String baby) {
    return '$baby has arrived!';
  }

  @override
  String activityMemberRemoved(String actor, String member) {
    return '$actor removed $member from the family';
  }

  @override
  String activityMemberRemovedUnnamed(String actor) {
    return '$actor removed a member from the family';
  }

  @override
  String activityMemberLeft(String actor) {
    return '$actor left the family';
  }

  @override
  String inboxPhotoShared(String actor) {
    return '$actor shared a new photo';
  }

  @override
  String inboxPhotoSquished(String actor) {
    return '$actor squished your photo';
  }

  @override
  String inboxPhotoCommented(String actor) {
    return '$actor commented on your photo';
  }

  @override
  String inboxEventCreated(String actor, String title) {
    return '$actor added \"$title\" to the calendar';
  }

  @override
  String inboxEventRsvp(String actor, String title, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'going': '$actor is going to \"$title\"',
      'maybe': '$actor might go to \"$title\"',
      'cant_go': '$actor can\'t make it to \"$title\"',
      'other': '$actor replied to \"$title\"',
    });
    return '$_temp0';
  }

  @override
  String inboxEventCommented(String actor, String title) {
    return '$actor commented on \"$title\"';
  }

  @override
  String inboxRegistryPurchased(String actor, String item) {
    return '$actor marked \"$item\" as purchased';
  }

  @override
  String inboxRegistryBuying(String actor, String item) {
    return '$actor is buying \"$item\"';
  }

  @override
  String inboxInviteAccepted(String actor, String baby) {
    return '$actor joined $baby';
  }

  @override
  String inboxBabyArrived(String baby) {
    return '$baby has arrived! See the announcement.';
  }

  @override
  String batchInviteMaxOwnersSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count co-owner invites were not sent: this baby profile already has the most owners it can have, counting pending co-owner invites.',
      one:
          '1 co-owner invite was not sent: this baby profile already has the most owners it can have, counting pending co-owner invites.',
    );
    return '$_temp0';
  }
}
