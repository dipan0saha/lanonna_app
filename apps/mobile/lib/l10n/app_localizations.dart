import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Digest, push, and channel preferences'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get settingsHelpSupport;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Use biometric unlock'**
  String get settingsBiometricUnlock;

  /// No description provided for @settingsBiometricUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require Face ID or fingerprint to open the app after you sign in'**
  String get settingsBiometricUnlockSubtitle;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are not available on this device.'**
  String get settingsBiometricUnavailable;

  /// No description provided for @biometricUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock La Nonna'**
  String get biometricUnlockReason;

  /// No description provided for @biometricUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get biometricUnlockTitle;

  /// No description provided for @biometricUnlockRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get biometricUnlockRetry;

  /// No description provided for @biometricUnlockSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get biometricUnlockSignOut;

  /// No description provided for @notificationChannelGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get notificationChannelGallery;

  /// No description provided for @notificationChannelGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New photos, squishes, and photo comments'**
  String get notificationChannelGallerySubtitle;

  /// No description provided for @notificationChannelCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get notificationChannelCalendar;

  /// No description provided for @notificationChannelCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New events and RSVPs'**
  String get notificationChannelCalendarSubtitle;

  /// No description provided for @notificationChannelRegistry.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get notificationChannelRegistry;

  /// No description provided for @notificationChannelRegistrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Registry purchases and updates'**
  String get notificationChannelRegistrySubtitle;

  /// No description provided for @notificationChannelComments.
  ///
  /// In en, this message translates to:
  /// **'Event comments'**
  String get notificationChannelComments;

  /// No description provided for @notificationChannelCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Comments on calendar events'**
  String get notificationChannelCommentsSubtitle;

  /// No description provided for @notificationPrefsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get notificationPrefsSave;

  /// No description provided for @notificationPrefsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get notificationPrefsSaving;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your La Nonna account. Any Baby Profiles solely owned by your account will also be deleted. Baby Profiles with a co owner will not be deleted; ownership will transfer fully to the co owner.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get deleteAccountDeleting;

  /// No description provided for @deleteAccountChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking whether your account can be deleted…'**
  String get deleteAccountChecking;

  /// No description provided for @deleteAccountBlocked.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot be deleted right now.'**
  String get deleteAccountBlocked;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account permanently?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your La Nonna account. Any Baby Profiles solely owned by your account will also be deleted. Baby Profiles with a co owner will not be deleted; ownership will transfer fully to the co owner.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountConfirmAction;

  /// No description provided for @deleteAccountSoleOwnedHeading.
  ///
  /// In en, this message translates to:
  /// **'These baby profiles will be deleted:'**
  String get deleteAccountSoleOwnedHeading;

  /// No description provided for @deleteAccountReauthPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get deleteAccountReauthPasswordTitle;

  /// No description provided for @deleteAccountReauthPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to delete your account.'**
  String get deleteAccountReauthPasswordBody;

  /// No description provided for @deleteAccountReauthPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get deleteAccountReauthPasswordAction;

  /// No description provided for @deleteAccountReauthFailed.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to delete your account.'**
  String get deleteAccountReauthFailed;

  /// No description provided for @emailVerifyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get emailVerifyHeadline;

  /// No description provided for @emailVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a message to {email} with a Verify my email button. Tap it to activate your account. If you do not see it, check spam or junk.'**
  String emailVerifyBody(String email);

  /// No description provided for @emailVerifyContinuePending.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet - open the newest email and tap Verify my email, then try Continue.'**
  String get emailVerifyContinuePending;

  /// No description provided for @emailVerifySent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get emailVerifySent;

  /// No description provided for @emailVerifyResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get emailVerifyResend;

  /// No description provided for @photoSquishCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 squishes} =1{1 squish} other{{count} squishes}}'**
  String photoSquishCount(int count);

  /// No description provided for @photoCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 comments} =1{1 comment} other{{count} comments}}'**
  String photoCommentCount(int count);

  /// No description provided for @predictionVoteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 votes} =1{1 vote} other{{count} votes}}'**
  String predictionVoteCount(int count);

  /// No description provided for @rsvpResponseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 responses} =1{1 response} other{{count} responses}}'**
  String rsvpResponseCount(int count);

  /// No description provided for @notificationPreferencesIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose how often you\'d like updates from {babyName}.'**
  String notificationPreferencesIntro(String babyName);

  /// Subtitle under AI Suggestions app bar (calendar + registry).
  ///
  /// In en, this message translates to:
  /// **'Pick a stage, then add suggestions to your calendar or registry.'**
  String get aiSuggestionsSubtitle;

  /// No description provided for @nameLoveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 loves} =1{1 love} other{{count} loves}}'**
  String nameLoveCount(int count);

  /// No description provided for @funBirthdateYourGuess.
  ///
  /// In en, this message translates to:
  /// **'Your guess: {date}'**
  String funBirthdateYourGuess(String date);

  /// No description provided for @funBirthdateSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {date}'**
  String funBirthdateSelected(String date);

  /// No description provided for @funBirthdateDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date: {label}'**
  String funBirthdateDueDate(String label);

  /// No description provided for @funBirthdateSaveGuess.
  ///
  /// In en, this message translates to:
  /// **'Save guess'**
  String get funBirthdateSaveGuess;

  /// No description provided for @funBirthdateUpdateGuess.
  ///
  /// In en, this message translates to:
  /// **'Update guess'**
  String get funBirthdateUpdateGuess;

  /// No description provided for @funBirthdatePickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date…'**
  String get funBirthdatePickDate;

  /// No description provided for @funBirthdateConfirmSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save birthdate guess?'**
  String get funBirthdateConfirmSaveTitle;

  /// No description provided for @funBirthdateConfirmSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your guess will be {date}. You can change it later.'**
  String funBirthdateConfirmSaveBody(String date);

  /// No description provided for @funBirthdateConfirmUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update birthdate guess?'**
  String get funBirthdateConfirmUpdateTitle;

  /// No description provided for @funBirthdateConfirmUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'Change your guess to {date}?'**
  String funBirthdateConfirmUpdateBody(String date);

  /// No description provided for @funBirthdateConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get funBirthdateConfirmAction;

  /// No description provided for @predictionsClosedNote.
  ///
  /// In en, this message translates to:
  /// **'Predictions closed — baby has arrived'**
  String get predictionsClosedNote;

  /// Shown above the read-only name list after the baby is born.
  ///
  /// In en, this message translates to:
  /// **'Name ideas are closed — baby has arrived.'**
  String get namesClosedNote;

  /// No description provided for @rsvpStatusGoing.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get rsvpStatusGoing;

  /// No description provided for @rsvpStatusMaybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get rsvpStatusMaybe;

  /// No description provided for @rsvpStatusCantGo.
  ///
  /// In en, this message translates to:
  /// **'Can\'t go'**
  String get rsvpStatusCantGo;

  /// No description provided for @authPasswordResetForgotLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authPasswordResetForgotLink;

  /// No description provided for @authPasswordResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authPasswordResetDialogTitle;

  /// No description provided for @authPasswordResetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email for your account. We\'ll send a reset link.'**
  String get authPasswordResetDialogBody;

  /// No description provided for @authPasswordResetEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authPasswordResetEmailLabel;

  /// No description provided for @authPasswordResetSend.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authPasswordResetSend;

  /// No description provided for @authPasswordResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authPasswordResetCancel;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a password reset link.'**
  String get authPasswordResetSent;

  /// No description provided for @authErrorIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password. Try again or reset your password.'**
  String get authErrorIncorrectCredentials;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact support for help.'**
  String get authErrorUserDisabled;

  /// No description provided for @authErrorEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email. Sign in instead.'**
  String get authErrorEmailAlreadyInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password (at least 6 characters).'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method isn\'t available. Try email and password.'**
  String get authErrorOperationNotAllowed;

  /// No description provided for @authErrorAccountExistsDifferentCredential.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with a different sign-in method. Try email and password.'**
  String get authErrorAccountExistsDifferentCredential;

  /// No description provided for @authErrorPasswordResetIfAccountExists.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, you\'ll receive a password reset link.'**
  String get authErrorPasswordResetIfAccountExists;

  /// No description provided for @authErrorGenericSignIn.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Please try again.'**
  String get authErrorGenericSignIn;

  /// No description provided for @authErrorGenericSignUp.
  ///
  /// In en, this message translates to:
  /// **'Could not create your account. Please try again.'**
  String get authErrorGenericSignUp;

  /// No description provided for @memberRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from family?'**
  String get memberRemoveConfirmTitle;

  /// No description provided for @memberRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will lose access to photos, events, and registry for this baby.'**
  String memberRemoveConfirmBody(String name);

  /// No description provided for @memberRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get memberRemoveAction;

  /// No description provided for @memberLeaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Leave profile'**
  String get memberLeaveProfile;

  /// No description provided for @memberLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this baby profile?'**
  String get memberLeaveConfirmTitle;

  /// No description provided for @memberLeaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to this baby\'s photos, calendar, and registry.'**
  String get memberLeaveConfirmBody;

  /// No description provided for @memberLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get memberLeaveAction;

  /// No description provided for @memberSoleOwnerLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t leave yet'**
  String get memberSoleOwnerLeaveTitle;

  /// No description provided for @memberSoleOwnerLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You are the only owner. Add a co-owner, delete this baby profile, or delete your account to leave.'**
  String get memberSoleOwnerLeaveBody;

  /// No description provided for @membershipEndedMessage.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to this profile.'**
  String get membershipEndedMessage;

  /// No description provided for @memberRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Member removed.'**
  String get memberRemovedSuccess;

  /// No description provided for @memberLeftSuccess.
  ///
  /// In en, this message translates to:
  /// **'You left this baby profile.'**
  String get memberLeftSuccess;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'La Nonna'**
  String get appTitle;

  /// No description provided for @appEmailVerifiedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Email verified. Sign in with the same address to continue.'**
  String get appEmailVerifiedSignIn;

  /// No description provided for @appEmailVerifyLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your email from this link.'**
  String get appEmailVerifyLinkFailed;

  /// No description provided for @batchInviteCoOwnerHintOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Selecting Wife or Husband makes that person a co-owner with the same edit access as you.'**
  String get batchInviteCoOwnerHintOnboarding;

  /// No description provided for @batchInviteCoOwnerHintManage.
  ///
  /// In en, this message translates to:
  /// **'💡 Selecting \"Mother\" or \"Father\" makes that person a co-owner of this baby profile, with the same edit access as you.'**
  String get batchInviteCoOwnerHintManage;

  /// No description provided for @batchInviteNoInvitesToSend.
  ///
  /// In en, this message translates to:
  /// **'No invites to send.'**
  String get batchInviteNoInvitesToSend;

  /// No description provided for @batchInviteAddEmailToSend.
  ///
  /// In en, this message translates to:
  /// **'Add at least one email address to send invites.'**
  String get batchInviteAddEmailToSend;

  /// No description provided for @batchInviteInvalidEmails.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email for each invite row.'**
  String get batchInviteInvalidEmails;

  /// No description provided for @batchInviteNoNewInvites.
  ///
  /// In en, this message translates to:
  /// **'No new invites to send for the emails entered.'**
  String get batchInviteNoNewInvites;

  /// No description provided for @batchInviteEmailQueueFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One invite was saved but the email could not be sent. Check Manage followers.} other{{count} invites were saved but emails could not be sent. Check Manage followers.}}'**
  String batchInviteEmailQueueFailed(int count);

  /// No description provided for @wrongEmailHeadline.
  ///
  /// In en, this message translates to:
  /// **'Wrong account'**
  String get wrongEmailHeadline;

  /// No description provided for @wrongEmailBody.
  ///
  /// In en, this message translates to:
  /// **'This invitation was sent to {invitee}, but you\'re signed in as {signedIn}. Sign in with the invited email to continue.'**
  String wrongEmailBody(String invitee, String signedIn);

  /// No description provided for @wrongEmailInviteeFallback.
  ///
  /// In en, this message translates to:
  /// **'the invited email'**
  String get wrongEmailInviteeFallback;

  /// No description provided for @wrongEmailSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get wrongEmailSwitchAccount;

  /// No description provided for @wrongEmailLeaveInvitation.
  ///
  /// In en, this message translates to:
  /// **'Leave this invitation'**
  String get wrongEmailLeaveInvitation;

  /// No description provided for @predictionGenderVoteShare.
  ///
  /// In en, this message translates to:
  /// **'{pct}% ({count})'**
  String predictionGenderVoteShare(int pct, int count);

  /// No description provided for @commentComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get commentComposerHint;

  /// No description provided for @commentSend.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get commentSend;

  /// No description provided for @commentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentEditTitle;

  /// No description provided for @commentEditHint.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentEditHint;

  /// No description provided for @commentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get commentDeleteTitle;

  /// No description provided for @commentSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commentSave;

  /// No description provided for @commentCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commentCancel;

  /// No description provided for @commentDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentDeleteAction;

  /// No description provided for @followerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 followers} =1{1 follower} other{{count} followers}}'**
  String followerCount(int count);

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @babyNameFallback.
  ///
  /// In en, this message translates to:
  /// **'your baby'**
  String get babyNameFallback;

  /// No description provided for @notificationsInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsInboxTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsInboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsInboxEmptyTitle;

  /// No description provided for @notificationsInboxEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'When family comments, RSVPs, or joins, you\'ll see it here.'**
  String get notificationsInboxEmptyMessage;

  /// No description provided for @inboxNotificationFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get inboxNotificationFallbackTitle;

  /// No description provided for @accountDigestFrequency.
  ///
  /// In en, this message translates to:
  /// **'Digest frequency'**
  String get accountDigestFrequency;

  /// No description provided for @homeBornActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Once family starts commenting and squishing photos, you\'ll see it here.'**
  String get homeBornActivityEmpty;

  /// No description provided for @calendarPastEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Past events'**
  String get calendarPastEventsTitle;

  /// No description provided for @calendarPastEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Events that have already happened'**
  String get calendarPastEventsSubtitle;

  /// No description provided for @calendarPastEventsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No past events yet.'**
  String get calendarPastEventsEmpty;

  /// No description provided for @calendarLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get calendarLoadMore;

  /// No description provided for @registrySortPriorityHighFirst.
  ///
  /// In en, this message translates to:
  /// **'Priority: High first'**
  String get registrySortPriorityHighFirst;

  /// No description provided for @registrySortPriorityLowFirst.
  ///
  /// In en, this message translates to:
  /// **'Priority: Low first'**
  String get registrySortPriorityLowFirst;

  /// No description provided for @versionGateUpdateInStore.
  ///
  /// In en, this message translates to:
  /// **'Update in store'**
  String get versionGateUpdateInStore;

  /// No description provided for @aiSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestions'**
  String get aiSuggestionsTitle;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @accountDateOfBirthOptional.
  ///
  /// In en, this message translates to:
  /// **'Date of birth (optional)'**
  String get accountDateOfBirthOptional;

  /// No description provided for @accountAddNewBaby.
  ///
  /// In en, this message translates to:
  /// **'+ Add New'**
  String get accountAddNewBaby;

  /// No description provided for @accountManageFollowers.
  ///
  /// In en, this message translates to:
  /// **'Manage Followers'**
  String get accountManageFollowers;

  /// No description provided for @accountInviteFamily.
  ///
  /// In en, this message translates to:
  /// **'Invite Family'**
  String get accountInviteFamily;

  /// No description provided for @accountExportBabyData.
  ///
  /// In en, this message translates to:
  /// **'Export baby data'**
  String get accountExportBabyData;

  /// No description provided for @exportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download export'**
  String get exportDownload;

  /// No description provided for @exportRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get exportRefreshStatus;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @followersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No followers yet — invite family to join.'**
  String get followersEmpty;

  /// No description provided for @actionRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get actionRevoke;

  /// No description provided for @actionResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get actionResend;

  /// No description provided for @notificationPrefsPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notificationPrefsPushTitle;

  /// No description provided for @notificationPrefsPushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get alerts on your phone'**
  String get notificationPrefsPushSubtitle;

  /// No description provided for @notificationPrefsDigestTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly email digest'**
  String get notificationPrefsDigestTitle;

  /// No description provided for @notificationPrefsDigestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos, events and registry updates'**
  String get notificationPrefsDigestSubtitle;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @accountLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get accountLogOut;

  /// No description provided for @announcementDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get announcementDateOfBirth;

  /// No description provided for @announcementTimeOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Time of birth'**
  String get announcementTimeOfBirth;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @noBabyProfileYet.
  ///
  /// In en, this message translates to:
  /// **'No baby profile yet.'**
  String get noBabyProfileYet;

  /// No description provided for @calendarPastButton.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get calendarPastButton;

  /// No description provided for @calendarUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get calendarUpcomingTitle;

  /// No description provided for @eventNoRsvps.
  ///
  /// In en, this message translates to:
  /// **'No RSVPs yet'**
  String get eventNoRsvps;

  /// No description provided for @eventDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get eventDeleteConfirmTitle;

  /// No description provided for @eventDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Family will no longer see it on the calendar.'**
  String get eventDeleteConfirmBody;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get eventNotFound;

  /// No description provided for @eventJoinVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Join video call'**
  String get eventJoinVideoCall;

  /// No description provided for @eventPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get eventPhotoLabel;

  /// No description provided for @eventCoverUploadNew.
  ///
  /// In en, this message translates to:
  /// **'Upload new photo'**
  String get eventCoverUploadNew;

  /// No description provided for @eventCoverNone.
  ///
  /// In en, this message translates to:
  /// **'No cover photo'**
  String get eventCoverNone;

  /// No description provided for @actionShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get actionShowAll;

  /// No description provided for @calendarAddEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get calendarAddEvent;

  /// No description provided for @funRemoveNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove name suggestion?'**
  String get funRemoveNameTitle;

  /// No description provided for @funRemoveNameBody.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from the list?'**
  String funRemoveNameBody(String name);

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @funGenderBoy.
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get funGenderBoy;

  /// No description provided for @funGenderGirl.
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get funGenderGirl;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @funViewWhoVoted.
  ///
  /// In en, this message translates to:
  /// **'View who voted'**
  String get funViewWhoVoted;

  /// No description provided for @photoDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get photoDeleteConfirmTitle;

  /// No description provided for @photoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Photo not found'**
  String get photoNotFound;

  /// No description provided for @photoProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get photoProcessing;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @photoSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoSourceCamera;

  /// No description provided for @photoSourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get photoSourceLibrary;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get actionPost;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get photoUnavailable;

  /// No description provided for @homeCreateAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'Create announcement?'**
  String get homeCreateAnnouncementTitle;

  /// No description provided for @actionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get actionLater;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @actionLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get actionLoadMore;

  /// No description provided for @actionManageFollowers.
  ///
  /// In en, this message translates to:
  /// **'Manage followers'**
  String get actionManageFollowers;

  /// No description provided for @actionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionDismiss;

  /// No description provided for @onboardingHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get onboardingHaveAccount;

  /// No description provided for @onboardingContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get onboardingContinueWithGoogle;

  /// No description provided for @onboardingAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the {terms} and {privacy}'**
  String onboardingAgreeToTerms(String terms, String privacy);

  /// No description provided for @onboardingTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get onboardingTermsOfService;

  /// No description provided for @onboardingPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get onboardingPrivacyPolicy;

  /// No description provided for @onboardingSignupAuthPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? {action}'**
  String onboardingSignupAuthPrompt(String action);

  /// No description provided for @onboardingLoginAuthPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? {action}'**
  String onboardingLoginAuthPrompt(String action);

  /// No description provided for @registryPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get registryPriorityLabel;

  /// No description provided for @registryPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Nice to have'**
  String get registryPriorityLow;

  /// No description provided for @registryPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'Really need this'**
  String get registryPriorityHigh;

  /// No description provided for @registryDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get registryDeleteItem;

  /// No description provided for @registryMarkPurchasedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as purchased?'**
  String get registryMarkPurchasedTitle;

  /// No description provided for @registryMarkPurchased.
  ///
  /// In en, this message translates to:
  /// **'Mark as purchased'**
  String get registryMarkPurchased;

  /// No description provided for @registryAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get registryAllCaughtUp;

  /// No description provided for @registryNothingPurchased.
  ///
  /// In en, this message translates to:
  /// **'Nothing purchased yet.'**
  String get registryNothingPurchased;

  /// No description provided for @shippingRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove shipping address?'**
  String get shippingRemoveTitle;

  /// No description provided for @shippingCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get shippingCountryLabel;

  /// No description provided for @shippingSave.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get shippingSave;

  /// No description provided for @shippingRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove address'**
  String get shippingRemove;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @searchSelectBaby.
  ///
  /// In en, this message translates to:
  /// **'Select a baby profile to search'**
  String get searchSelectBaby;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchNoResults(String query);

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @babySwitcherEmpty.
  ///
  /// In en, this message translates to:
  /// **'No baby profiles yet.'**
  String get babySwitcherEmpty;

  /// No description provided for @babySwitcherEditBaby.
  ///
  /// In en, this message translates to:
  /// **'Edit baby'**
  String get babySwitcherEditBaby;

  /// No description provided for @babySwitcherMyAccount.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get babySwitcherMyAccount;

  /// No description provided for @babySwitcherAddBaby.
  ///
  /// In en, this message translates to:
  /// **'Add New Baby'**
  String get babySwitcherAddBaby;

  /// No description provided for @actionAdd2.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get actionAdd2;

  /// No description provided for @actionInviteMorePeople.
  ///
  /// In en, this message translates to:
  /// **'+ Invite more people'**
  String get actionInviteMorePeople;

  /// No description provided for @label123MainSt.
  ///
  /// In en, this message translates to:
  /// **'123 Main St'**
  String get label123MainSt;

  /// No description provided for @stage36Months.
  ///
  /// In en, this message translates to:
  /// **'3–6 months'**
  String get stage36Months;

  /// No description provided for @stage612Months.
  ///
  /// In en, this message translates to:
  /// **'6–12 months'**
  String get stage612Months;

  /// No description provided for @labelAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get labelAccount;

  /// No description provided for @actionAddBaby.
  ///
  /// In en, this message translates to:
  /// **'Add Baby'**
  String get actionAddBaby;

  /// No description provided for @actionAddEvent.
  ///
  /// In en, this message translates to:
  /// **'Add Event'**
  String get actionAddEvent;

  /// No description provided for @registryAddItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get registryAddItemTitle;

  /// No description provided for @actionAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get actionAddPhoto;

  /// No description provided for @actionAddPhoto2.
  ///
  /// In en, this message translates to:
  /// **'Add a Photo'**
  String get actionAddPhoto2;

  /// No description provided for @actionAddCalendarEvent.
  ///
  /// In en, this message translates to:
  /// **'Add a calendar event'**
  String get actionAddCalendarEvent;

  /// No description provided for @actionAddCaption.
  ///
  /// In en, this message translates to:
  /// **'Add a caption…'**
  String get actionAddCaption;

  /// No description provided for @actionAddName.
  ///
  /// In en, this message translates to:
  /// **'Add a name...'**
  String get actionAddName;

  /// No description provided for @actionAddRegistryItem.
  ///
  /// In en, this message translates to:
  /// **'Add a registry item'**
  String get actionAddRegistryItem;

  /// No description provided for @actionAddShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a short description…'**
  String get actionAddShortDescription;

  /// No description provided for @actionAddAddressKnows.
  ///
  /// In en, this message translates to:
  /// **'Add an address so family knows where to send gifts.'**
  String get actionAddAddressKnows;

  /// No description provided for @actionAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get actionAddAnother;

  /// No description provided for @actionAddBaby2.
  ///
  /// In en, this message translates to:
  /// **'Add baby'**
  String get actionAddBaby2;

  /// No description provided for @registryAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get registryAddItem;

  /// No description provided for @actionAddPhoto3.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get actionAddPhoto3;

  /// No description provided for @actionAddGallery.
  ///
  /// In en, this message translates to:
  /// **'Add to gallery'**
  String get actionAddGallery;

  /// No description provided for @actionAddFirstBabyProfile.
  ///
  /// In en, this message translates to:
  /// **'Add your first baby profile to get started.'**
  String get actionAddFirstBabyProfile;

  /// No description provided for @messageSuggestionsStage.
  ///
  /// In en, this message translates to:
  /// **'All suggestions in this stage are on your calendar.'**
  String get messageSuggestionsStage;

  /// No description provided for @messageSuggestionsStage2.
  ///
  /// In en, this message translates to:
  /// **'All suggestions in this stage are on your registry.'**
  String get messageSuggestionsStage2;

  /// No description provided for @hintSharePhoto.
  ///
  /// In en, this message translates to:
  /// **'Also share this photo in the gallery'**
  String get hintSharePhoto;

  /// No description provided for @actionAnnounceArrival.
  ///
  /// In en, this message translates to:
  /// **'Announce Arrival'**
  String get actionAnnounceArrival;

  /// No description provided for @actionAnnounceArrival2.
  ///
  /// In en, this message translates to:
  /// **'Announce arrival'**
  String get actionAnnounceArrival2;

  /// No description provided for @announcementTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get announcementTitle;

  /// No description provided for @fieldApt4b.
  ///
  /// In en, this message translates to:
  /// **'Apt 4B'**
  String get fieldApt4b;

  /// No description provided for @fieldAptSuiteEtcOptional.
  ///
  /// In en, this message translates to:
  /// **'Apt, suite, etc. (optional)'**
  String get fieldAptSuiteEtcOptional;

  /// No description provided for @labelBoyGirl.
  ///
  /// In en, this message translates to:
  /// **'BOY OR GIRL?'**
  String get labelBoyGirl;

  /// No description provided for @labelBabyProfiles.
  ///
  /// In en, this message translates to:
  /// **'Baby Profiles'**
  String get labelBabyProfiles;

  /// No description provided for @labelBabyShower.
  ///
  /// In en, this message translates to:
  /// **'Baby Shower'**
  String get labelBabyShower;

  /// No description provided for @labelBabyName.
  ///
  /// In en, this message translates to:
  /// **'Baby name'**
  String get labelBabyName;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @presetBaptism.
  ///
  /// In en, this message translates to:
  /// **'Baptism'**
  String get presetBaptism;

  /// No description provided for @labelBirthdateGuesses.
  ///
  /// In en, this message translates to:
  /// **'Birthdate guesses'**
  String get labelBirthdateGuesses;

  /// No description provided for @presetBottles.
  ///
  /// In en, this message translates to:
  /// **'Bottles'**
  String get presetBottles;

  /// No description provided for @labelBoyGirl2.
  ///
  /// In en, this message translates to:
  /// **'Boy or Girl?'**
  String get labelBoyGirl2;

  /// No description provided for @labelBoySNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Boy\'s name (optional)'**
  String get labelBoySNameOptional;

  /// No description provided for @announcementCommentsHeading.
  ///
  /// In en, this message translates to:
  /// **'COMMENTS'**
  String get announcementCommentsHeading;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCity;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @fieldCountryOptional.
  ///
  /// In en, this message translates to:
  /// **'Country (optional)'**
  String get fieldCountryOptional;

  /// No description provided for @fieldCoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get fieldCoverPhoto;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @actionCreateBabyProfileUse.
  ///
  /// In en, this message translates to:
  /// **'Create a baby profile to use Gallery.'**
  String get actionCreateBabyProfileUse;

  /// No description provided for @actionCreatePassword.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get actionCreatePassword;

  /// No description provided for @calendarCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get calendarCreateEvent;

  /// No description provided for @presetCribMattress.
  ///
  /// In en, this message translates to:
  /// **'Crib & Mattress'**
  String get presetCribMattress;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @eventDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get eventDeleteAction;

  /// No description provided for @registryDeleteItemAction.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get registryDeleteItemAction;

  /// No description provided for @actionDeletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get actionDeletePhoto;

  /// No description provided for @fieldDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get fieldDescriptionOptional;

  /// No description provided for @eventDetailsHeading.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get eventDetailsHeading;

  /// No description provided for @presetDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers'**
  String get presetDiapers;

  /// No description provided for @actionDownloadJsonCopy.
  ///
  /// In en, this message translates to:
  /// **'Download a JSON copy of this baby\'s profile, members, photos and comments, calendar and RSVPs, registry and purchases, name ideas, predictions, the birth announcement, and recent activity.'**
  String get actionDownloadJsonCopy;

  /// No description provided for @presetDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get presetDueDate;

  /// No description provided for @actionEditBaby.
  ///
  /// In en, this message translates to:
  /// **'Edit Baby'**
  String get actionEditBaby;

  /// No description provided for @actionEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get actionEditProfile;

  /// No description provided for @actionEditAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Edit announcement'**
  String get actionEditAnnouncement;

  /// No description provided for @actionEditCaption.
  ///
  /// In en, this message translates to:
  /// **'Edit caption'**
  String get actionEditCaption;

  /// No description provided for @eventEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventEditAction;

  /// No description provided for @registryEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get registryEditItem;

  /// No description provided for @labelEmailPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get labelEmailPhone;

  /// No description provided for @hintEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get hintEnterPassword;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventTitle;

  /// No description provided for @fieldEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Title'**
  String get fieldEventTitle;

  /// No description provided for @searchSectionEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get searchSectionEvents;

  /// No description provided for @stageExpecting.
  ///
  /// In en, this message translates to:
  /// **'Expecting'**
  String get stageExpecting;

  /// No description provided for @messageFun.
  ///
  /// In en, this message translates to:
  /// **'Family Fun'**
  String get messageFun;

  /// No description provided for @messageInsight.
  ///
  /// In en, this message translates to:
  /// **'Family Insight'**
  String get messageInsight;

  /// No description provided for @messageItem.
  ///
  /// In en, this message translates to:
  /// **'Family will see this item as taken so no one buys it again.'**
  String get messageItem;

  /// No description provided for @presetFirstCheckup.
  ///
  /// In en, this message translates to:
  /// **'First Checkup'**
  String get presetFirstCheckup;

  /// No description provided for @presetFirstHolidays.
  ///
  /// In en, this message translates to:
  /// **'First Holidays'**
  String get presetFirstHolidays;

  /// No description provided for @fieldFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get fieldFirstName;

  /// No description provided for @messageFollowersLonger.
  ///
  /// In en, this message translates to:
  /// **'Followers will no longer see where to send gifts.'**
  String get messageFollowersLonger;

  /// No description provided for @navFun.
  ///
  /// In en, this message translates to:
  /// **'Fun'**
  String get navFun;

  /// No description provided for @labelGenderReveal.
  ///
  /// In en, this message translates to:
  /// **'Gender Reveal'**
  String get labelGenderReveal;

  /// No description provided for @labelGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get labelGettingStarted;

  /// No description provided for @labelGirlSNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Girl\'s name (optional)'**
  String get labelGirlSNameOptional;

  /// No description provided for @actionGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get actionGoHome;

  /// No description provided for @brandGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get brandGoogle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @labelIl.
  ///
  /// In en, this message translates to:
  /// **'IL'**
  String get labelIl;

  /// No description provided for @labelPhoto.
  ///
  /// In en, this message translates to:
  /// **'IN THIS PHOTO'**
  String get labelPhoto;

  /// No description provided for @actionInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get actionInvite;

  /// No description provided for @actionInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite Family & Friends'**
  String get actionInviteFriends;

  /// No description provided for @actionInviteStatus.
  ///
  /// In en, this message translates to:
  /// **'Invite Status'**
  String get actionInviteStatus;

  /// No description provided for @actionInviteMorePeople2.
  ///
  /// In en, this message translates to:
  /// **'Invite more people'**
  String get actionInviteMorePeople2;

  /// No description provided for @fieldItemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get fieldItemName;

  /// No description provided for @fieldLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get fieldLastName;

  /// No description provided for @announcementLengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get announcementLengthLabel;

  /// No description provided for @fieldLinkOptional.
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get fieldLinkOptional;

  /// No description provided for @fieldLocationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get fieldLocationOptional;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// No description provided for @labelMyAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get labelMyAccount;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @searchSectionNames.
  ///
  /// In en, this message translates to:
  /// **'Names'**
  String get searchSectionNames;

  /// No description provided for @registrySectionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get registrySectionNeeded;

  /// No description provided for @labelNewFollowers.
  ///
  /// In en, this message translates to:
  /// **'New Followers'**
  String get labelNewFollowers;

  /// No description provided for @stageNewborn03mo.
  ///
  /// In en, this message translates to:
  /// **'Newborn (0–3mo)'**
  String get stageNewborn03mo;

  /// No description provided for @actionNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get actionNextUp;

  /// No description provided for @actionNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get actionNextMonth;

  /// No description provided for @actionNextPhoto.
  ///
  /// In en, this message translates to:
  /// **'Next photo'**
  String get actionNextPhoto;

  /// No description provided for @emptyAnnouncementYet.
  ///
  /// In en, this message translates to:
  /// **'No announcement yet'**
  String get emptyAnnouncementYet;

  /// No description provided for @emptyEventsDay.
  ///
  /// In en, this message translates to:
  /// **'No events this day.'**
  String get emptyEventsDay;

  /// No description provided for @emptyEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get emptyEventsYet;

  /// No description provided for @emptyVotesYetCheckBack.
  ///
  /// In en, this message translates to:
  /// **'No family votes yet. Check back once everyone starts playing along in Fun.'**
  String get emptyVotesYetCheckBack;

  /// No description provided for @emptyFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get emptyFavoritesYet;

  /// No description provided for @emptyFurtherUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No further upcoming events'**
  String get emptyFurtherUpcomingEvents;

  /// No description provided for @emptyNameSuggestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No name suggestions yet'**
  String get emptyNameSuggestionsYet;

  /// No description provided for @emptyPhotosLast30.
  ///
  /// In en, this message translates to:
  /// **'No photos in the last 30 days. Upload a new moment or browse the full gallery.'**
  String get emptyPhotosLast30;

  /// No description provided for @emptyPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get emptyPhotosYet;

  /// No description provided for @emptyRecentPhotos.
  ///
  /// In en, this message translates to:
  /// **'No recent photos'**
  String get emptyRecentPhotos;

  /// No description provided for @registryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No registry items yet'**
  String get registryEmptyTitle;

  /// No description provided for @calendarNoUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get calendarNoUpcomingEvents;

  /// No description provided for @emptyVotesYetInvite.
  ///
  /// In en, this message translates to:
  /// **'No votes yet. Invite family so they can guess names, gender, and the big day.'**
  String get emptyVotesYetInvite;

  /// No description provided for @hintSureStart.
  ///
  /// In en, this message translates to:
  /// **'Not sure where to start? See AI-suggested events by stage and age.'**
  String get hintSureStart;

  /// No description provided for @hintSureStart2.
  ///
  /// In en, this message translates to:
  /// **'Not sure where to start? See AI-suggested items by stage and age.'**
  String get hintSureStart2;

  /// No description provided for @hintWasMeant.
  ///
  /// In en, this message translates to:
  /// **'Not who this was meant for?'**
  String get hintWasMeant;

  /// No description provided for @notificationPrefsChannelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification channels'**
  String get notificationPrefsChannelsTitle;

  /// No description provided for @notificationPrefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPrefsTitle;

  /// No description provided for @labelNotificationsProfileHelp.
  ///
  /// In en, this message translates to:
  /// **'Notifications, profile, and help'**
  String get labelNotificationsProfileHelp;

  /// No description provided for @hintDefaultFollowers.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Followers only see gallery photos you choose to share.'**
  String get hintDefaultFollowers;

  /// No description provided for @presetOnesies.
  ///
  /// In en, this message translates to:
  /// **'Onesies'**
  String get presetOnesies;

  /// No description provided for @actionOpenPhoto.
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get actionOpenPhoto;

  /// No description provided for @labelPrivateOrganizedConnected.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE. ORGANIZED. CONNECTED.'**
  String get labelPrivateOrganizedConnected;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @hintPasteZoomFacetimeLink.
  ///
  /// In en, this message translates to:
  /// **'Paste a Zoom / FaceTime link'**
  String get hintPasteZoomFacetimeLink;

  /// No description provided for @hintPasteLinkItem.
  ///
  /// In en, this message translates to:
  /// **'Paste a link to the item'**
  String get hintPasteLinkItem;

  /// No description provided for @labelPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'Pending invites'**
  String get labelPendingInvites;

  /// No description provided for @fieldPhoneNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone number (optional)'**
  String get fieldPhoneNumberOptional;

  /// No description provided for @searchSectionPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get searchSectionPhotos;

  /// No description provided for @labelPopularDates.
  ///
  /// In en, this message translates to:
  /// **'Popular Dates'**
  String get labelPopularDates;

  /// No description provided for @labelPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get labelPreferences;

  /// No description provided for @actionPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get actionPreviousMonth;

  /// No description provided for @actionPreviousPhoto.
  ///
  /// In en, this message translates to:
  /// **'Previous photo'**
  String get actionPreviousPhoto;

  /// No description provided for @registrySectionPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get registrySectionPurchased;

  /// No description provided for @labelQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get labelQuickActions;

  /// No description provided for @eventRsvpsTitle.
  ///
  /// In en, this message translates to:
  /// **'RSVPs'**
  String get eventRsvpsTitle;

  /// No description provided for @labelRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get labelRecentActivity;

  /// No description provided for @labelRecentPhotos.
  ///
  /// In en, this message translates to:
  /// **'Recent Photos'**
  String get labelRecentPhotos;

  /// No description provided for @onboardingRemoveInvite.
  ///
  /// In en, this message translates to:
  /// **'Remove invite'**
  String get onboardingRemoveInvite;

  /// No description provided for @actionResendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Resend invitation'**
  String get actionResendInvitation;

  /// No description provided for @actionRevokeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Revoke invitation'**
  String get actionRevokeInvitation;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @fieldSearchPhotosEventsRegistry.
  ///
  /// In en, this message translates to:
  /// **'Search photos, events, registry…'**
  String get fieldSearchPhotosEventsRegistry;

  /// No description provided for @fieldSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select a country'**
  String get fieldSelectCountry;

  /// No description provided for @fieldSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get fieldSelectDate;

  /// No description provided for @fieldSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select a time'**
  String get fieldSelectTime;

  /// No description provided for @actionSendInvites.
  ///
  /// In en, this message translates to:
  /// **'Send Invites'**
  String get actionSendInvites;

  /// No description provided for @actionShareKeepsakeCardPhoto.
  ///
  /// In en, this message translates to:
  /// **'Share a keepsake card with photo and birth details for family.'**
  String get actionShareKeepsakeCardPhoto;

  /// No description provided for @actionShareAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Share announcement'**
  String get actionShareAnnouncement;

  /// No description provided for @actionShareAnnouncementInstagram.
  ///
  /// In en, this message translates to:
  /// **'Share announcement to Instagram'**
  String get actionShareAnnouncementInstagram;

  /// No description provided for @actionShareNews.
  ///
  /// In en, this message translates to:
  /// **'Share the news with family. They will see a keepsake card with photo and details.'**
  String get actionShareNews;

  /// No description provided for @messageSharedAcrossEveryBabyProfile.
  ///
  /// In en, this message translates to:
  /// **'Shared across every baby profile you own. Free tier includes 15 GB.'**
  String get messageSharedAcrossEveryBabyProfile;

  /// No description provided for @shippingAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipping address'**
  String get shippingAddressTitle;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @actionSkipNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get actionSkipNow;

  /// No description provided for @labelSpringfield.
  ///
  /// In en, this message translates to:
  /// **'Springfield'**
  String get labelSpringfield;

  /// No description provided for @messageSquishPhotosLove.
  ///
  /// In en, this message translates to:
  /// **'Squish photos you love and they will show up here.'**
  String get messageSquishPhotosLove;

  /// No description provided for @hintStandardSizeGreenguardGoldCertified.
  ///
  /// In en, this message translates to:
  /// **'Standard size, GREENGUARD Gold certified…'**
  String get hintStandardSizeGreenguardGoldCertified;

  /// No description provided for @fieldStateProvinceOptional.
  ///
  /// In en, this message translates to:
  /// **'State / Province (optional)'**
  String get fieldStateProvinceOptional;

  /// No description provided for @labelStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get labelStorage;

  /// No description provided for @fieldStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get fieldStreetAddress;

  /// No description provided for @labelSuggestName.
  ///
  /// In en, this message translates to:
  /// **'Suggest a name'**
  String get labelSuggestName;

  /// No description provided for @labelSuggestName2.
  ///
  /// In en, this message translates to:
  /// **'Suggest a name…'**
  String get labelSuggestName2;

  /// No description provided for @presetSwaddles.
  ///
  /// In en, this message translates to:
  /// **'Swaddles'**
  String get presetSwaddles;

  /// No description provided for @actionSwitchBabyProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch baby profile'**
  String get actionSwitchBabyProfile;

  /// No description provided for @babySwitcherSwitchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get babySwitcherSwitchProfile;

  /// No description provided for @labelTopGuessDate.
  ///
  /// In en, this message translates to:
  /// **'TOP GUESS DATE'**
  String get labelTopGuessDate;

  /// No description provided for @labelTopName.
  ///
  /// In en, this message translates to:
  /// **'TOP NAME'**
  String get labelTopName;

  /// No description provided for @messageRemoves.
  ///
  /// In en, this message translates to:
  /// **'This removes it for everyone who can see it - this can\'t be undone.'**
  String get messageRemoves;

  /// No description provided for @messageStartTime.
  ///
  /// In en, this message translates to:
  /// **'This start time is in the past. The event still appears on the month grid and under Today on Calendar, but not in Upcoming.'**
  String get messageStartTime;

  /// No description provided for @fieldTimeOptional.
  ///
  /// In en, this message translates to:
  /// **'Time (optional)'**
  String get fieldTimeOptional;

  /// No description provided for @labelToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get labelToday;

  /// No description provided for @hintTypeSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search'**
  String get hintTypeSearch;

  /// No description provided for @registryUndoPurchase.
  ///
  /// In en, this message translates to:
  /// **'Undo purchase'**
  String get registryUndoPurchase;

  /// No description provided for @labelUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get labelUpcoming;

  /// No description provided for @labelUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get labelUpcomingEvents;

  /// No description provided for @versionGateUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get versionGateUpdateRequired;

  /// No description provided for @actionUploadFirstPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload your first photo'**
  String get actionUploadFirstPhoto;

  /// No description provided for @messageVerificationCompleteTapContinueProceed.
  ///
  /// In en, this message translates to:
  /// **'Verification complete. Tap Continue to proceed.'**
  String get messageVerificationCompleteTapContinueProceed;

  /// No description provided for @eventVideoCallLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Call'**
  String get eventVideoCallLabel;

  /// No description provided for @fieldVideoCallLinkOptional.
  ///
  /// In en, this message translates to:
  /// **'Video call link (optional)'**
  String get fieldVideoCallLinkOptional;

  /// No description provided for @actionViewGallery.
  ///
  /// In en, this message translates to:
  /// **'View Gallery'**
  String get actionViewGallery;

  /// No description provided for @actionViewRsvps.
  ///
  /// In en, this message translates to:
  /// **'View RSVPs ›'**
  String get actionViewRsvps;

  /// No description provided for @actionView.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get actionView;

  /// No description provided for @actionViewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'View announcement'**
  String get actionViewAnnouncement;

  /// No description provided for @actionVoteFun.
  ///
  /// In en, this message translates to:
  /// **'Vote in Fun'**
  String get actionVoteFun;

  /// No description provided for @announcementWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get announcementWeightLabel;

  /// No description provided for @hintShouldSendRegistryGifts.
  ///
  /// In en, this message translates to:
  /// **'Where should family send registry gifts?'**
  String get hintShouldSendRegistryGifts;

  /// No description provided for @labelVoted.
  ///
  /// In en, this message translates to:
  /// **'Who voted'**
  String get labelVoted;

  /// No description provided for @messageChangeTime.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time.'**
  String get messageChangeTime;

  /// No description provided for @messageSuggestName.
  ///
  /// In en, this message translates to:
  /// **'You can suggest 1 name per gender.'**
  String get messageSuggestName;

  /// No description provided for @messageReOfficiallyOwner.
  ///
  /// In en, this message translates to:
  /// **'You\'re officially an Owner!'**
  String get messageReOfficiallyOwner;

  /// No description provided for @messageReOfflineCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection.'**
  String get messageReOfflineCheckConnection;

  /// No description provided for @messageVeReachedEnd.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end of the gallery.'**
  String get messageVeReachedEnd;

  /// No description provided for @fieldZipPostalCode.
  ///
  /// In en, this message translates to:
  /// **'Zip / Postal code'**
  String get fieldZipPostalCode;

  /// No description provided for @fieldZipPostalCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Zip / Postal code (optional)'**
  String get fieldZipPostalCodeOptional;

  /// No description provided for @labelEG94103.
  ///
  /// In en, this message translates to:
  /// **'e.g. 94103'**
  String get labelEG94103;

  /// No description provided for @labelEGCribMattress.
  ///
  /// In en, this message translates to:
  /// **'e.g. Crib & Mattress'**
  String get labelEGCribMattress;

  /// No description provided for @labelEGGenderRevealParty.
  ///
  /// In en, this message translates to:
  /// **'e.g. Gender Reveal Party'**
  String get labelEGGenderRevealParty;

  /// No description provided for @labelEGGrandmaSueSBackyard.
  ///
  /// In en, this message translates to:
  /// **'e.g. Grandma Sue\'s backyard'**
  String get labelEGGrandmaSueSBackyard;

  /// No description provided for @labelEGLiam.
  ///
  /// In en, this message translates to:
  /// **'e.g. Liam'**
  String get labelEGLiam;

  /// No description provided for @labelEGOlivia.
  ///
  /// In en, this message translates to:
  /// **'e.g. Olivia'**
  String get labelEGOlivia;

  /// No description provided for @labelSignEmail.
  ///
  /// In en, this message translates to:
  /// **'or sign in with email'**
  String get labelSignEmail;

  /// No description provided for @labelSignUpEmail.
  ///
  /// In en, this message translates to:
  /// **'or sign up with email'**
  String get labelSignUpEmail;

  /// No description provided for @messageEmailCom.
  ///
  /// In en, this message translates to:
  /// **'you@email.com'**
  String get messageEmailCom;

  /// No description provided for @messagePerson.
  ///
  /// In en, this message translates to:
  /// **'👑 This person will also be a Baby Profile Owner'**
  String get messagePerson;

  /// No description provided for @commentDeleteMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get commentDeleteMenuLabel;

  /// No description provided for @versionGateUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This version ({installedVersion}) is no longer supported. Install {minimumVersion} or newer to continue.'**
  String versionGateUnsupported(String installedVersion, String minimumVersion);

  /// No description provided for @chipRemoveSemantics.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String chipRemoveSemantics(String label);

  /// No description provided for @registryPriorityShort.
  ///
  /// In en, this message translates to:
  /// **'P{priority}'**
  String registryPriorityShort(int priority);

  /// No description provided for @notificationPrefsFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'How often would you like updates for {babyLabel}?'**
  String notificationPrefsFrequencyTitle(String babyLabel);

  /// No description provided for @accountStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota} used'**
  String accountStorageUsed(String used, String quota);

  /// No description provided for @funRemoveNameSemantics.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String funRemoveNameSemantics(String name);

  /// No description provided for @predictionYourGenderVote.
  ///
  /// In en, this message translates to:
  /// **'Your vote: {vote}'**
  String predictionYourGenderVote(String vote);

  /// No description provided for @photoUploadedBy.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {meta} by {name}'**
  String photoUploadedBy(String meta, String name);

  /// No description provided for @photoTaggedBabies.
  ///
  /// In en, this message translates to:
  /// **'In this photo: {names}'**
  String photoTaggedBabies(String names);

  /// No description provided for @homeBirthWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is here!'**
  String homeBirthWelcomeTitle(String name);

  /// No description provided for @homeWaitingFor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String homeWaitingFor(String name);

  /// No description provided for @inviteCoOwnerAccessBody.
  ///
  /// In en, this message translates to:
  /// **'You now have full access to edit {babyName}\'\'s profile, add events, manage the registry, and invite others, just like {inviterName}.'**
  String inviteCoOwnerAccessBody(String babyName, String inviterName);

  /// No description provided for @emailVerifyDevAddressHint.
  ///
  /// In en, this message translates to:
  /// **'This looks like a dev-only address - it may not receive mail. Mark the account verified in Firebase Console, or use a real email.'**
  String get emailVerifyDevAddressHint;

  /// No description provided for @registryPurchasedBy.
  ///
  /// In en, this message translates to:
  /// **'Purchased by {name}'**
  String registryPurchasedBy(String name);

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(String status);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
