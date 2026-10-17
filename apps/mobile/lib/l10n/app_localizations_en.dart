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
  String get navSearch => 'Search';

  @override
  String get fieldSearchPhotosEventsRegistry =>
      'Search photos, events, registry…';

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
  String get hintTypeSearch => 'Type to search';

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
}
