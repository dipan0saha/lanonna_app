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
  /// **'Loading account details…'**
  String get deleteAccountChecking;

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

  /// One bullet in the list of baby profiles deleted with the account.
  ///
  /// In en, this message translates to:
  /// **'• {name}'**
  String deleteAccountSoleOwnedBaby(String name);

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
  /// **'You are the only owner. Add a co-owner and leave, delete the baby profile from Edit baby, or delete your account.'**
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

  /// No description provided for @deleteBabyProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Delete baby profile'**
  String get deleteBabyProfileAction;

  /// No description provided for @deleteBabyProfileConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this baby profile?'**
  String get deleteBabyProfileConfirmTitle;

  /// No description provided for @deleteBabyProfileConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {babyName} for everyone who follows this profile. Photos, calendar events, registry items, and other data will no longer be available in the app.'**
  String deleteBabyProfileConfirmBody(String babyName);

  /// No description provided for @deleteBabyProfileConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteBabyProfileConfirmAction;

  /// No description provided for @deleteBabyProfileFinalTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {babyName} permanently?'**
  String deleteBabyProfileFinalTitle(String babyName);

  /// No description provided for @deleteBabyProfileFinalBody.
  ///
  /// In en, this message translates to:
  /// **'Followers will lose access immediately. This cannot be undone.'**
  String get deleteBabyProfileFinalBody;

  /// No description provided for @deleteBabyProfileSuccess.
  ///
  /// In en, this message translates to:
  /// **'Baby profile deleted.'**
  String get deleteBabyProfileSuccess;

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

  /// No description provided for @shellInviteRequiresOwnerBabyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a baby profile first'**
  String get shellInviteRequiresOwnerBabyTitle;

  /// No description provided for @shellInviteRequiresOwnerBabyMessage.
  ///
  /// In en, this message translates to:
  /// **'Invites are sent from a baby profile you own. Create one, then invite family and friends.'**
  String get shellInviteRequiresOwnerBabyMessage;

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

  /// No description provided for @lifecycleBorn.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get lifecycleBorn;

  /// No description provided for @genderBoy.
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get genderBoy;

  /// No description provided for @genderGirl.
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get genderGirl;

  /// No description provided for @genderNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get genderNotSure;

  /// No description provided for @exportStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get exportStatusPending;

  /// No description provided for @exportStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get exportStatusRunning;

  /// No description provided for @exportStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get exportStatusReady;

  /// No description provided for @exportStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get exportStatusFailed;

  /// No description provided for @digestRealtime.
  ///
  /// In en, this message translates to:
  /// **'Real-time'**
  String get digestRealtime;

  /// No description provided for @digestDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily digest'**
  String get digestDaily;

  /// No description provided for @digestWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly digest'**
  String get digestWeekly;

  /// No description provided for @digestSummaryRealtime.
  ///
  /// In en, this message translates to:
  /// **'Real-time updates'**
  String get digestSummaryRealtime;

  /// No description provided for @digestSummaryDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily email summary'**
  String get digestSummaryDaily;

  /// No description provided for @digestSummaryWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly email summary'**
  String get digestSummaryWeekly;

  /// No description provided for @invitationStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get invitationStatusPending;

  /// No description provided for @invitationStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get invitationStatusAccepted;

  /// No description provided for @invitationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get invitationStatusExpired;

  /// No description provided for @invitationStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get invitationStatusRevoked;

  /// No description provided for @inviteEmailPending.
  ///
  /// In en, this message translates to:
  /// **'Pending — email sending'**
  String get inviteEmailPending;

  /// No description provided for @inviteEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Invite email sent'**
  String get inviteEmailSent;

  /// No description provided for @inviteEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Email failed to send'**
  String get inviteEmailFailed;

  /// No description provided for @commonMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get commonMe;

  /// No description provided for @settingsCouldNotOpenEmailTo.
  ///
  /// In en, this message translates to:
  /// **'Could not open email to {supportEmail}. Copy link?'**
  String settingsCouldNotOpenEmailTo(String supportEmail);

  /// No description provided for @homeConfirmTheDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Confirm the date of birth. Your home will update to celebrate your baby.'**
  String get homeConfirmTheDateOfBirth;

  /// No description provided for @homeDateOfBirthCannotBe.
  ///
  /// In en, this message translates to:
  /// **'Date of birth cannot be in the future.'**
  String get homeDateOfBirthCannotBe;

  /// No description provided for @homeYoullBeNotifiedTheMoment.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be notified the moment {babyName} arrives.'**
  String homeYoullBeNotifiedTheMoment(String babyName);

  /// No description provided for @homeViewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'🎀 View Announcement'**
  String get homeViewAnnouncement;

  /// No description provided for @homeShareToInstagram.
  ///
  /// In en, this message translates to:
  /// **'📸 Share to Instagram'**
  String get homeShareToInstagram;

  /// No description provided for @homeEveryoneYouveInvitedHasBeen.
  ///
  /// In en, this message translates to:
  /// **'Everyone you\'ve invited has been notified.'**
  String get homeEveryoneYouveInvitedHasBeen;

  /// No description provided for @homeDaysToDueDate.
  ///
  /// In en, this message translates to:
  /// **'Days to due date · {dueDateLabel}'**
  String homeDaysToDueDate(String dueDateLabel);

  /// No description provided for @homeDaysToDueDateHeading.
  ///
  /// In en, this message translates to:
  /// **'DAYS TO DUE DATE'**
  String get homeDaysToDueDateHeading;

  /// No description provided for @homeCouldNotUpdateBaby.
  ///
  /// In en, this message translates to:
  /// **'Could not update baby: {reason}'**
  String homeCouldNotUpdateBaby(String reason);

  /// No description provided for @calendarOnlyOwnersCanCreateOr.
  ///
  /// In en, this message translates to:
  /// **'Only owners can create or edit calendar events.'**
  String get calendarOnlyOwnersCanCreateOr;

  /// No description provided for @calendarBabyProfileIsStillLoading.
  ///
  /// In en, this message translates to:
  /// **'Baby profile is still loading. Try again.'**
  String get calendarBabyProfileIsStillLoading;

  /// No description provided for @calendarEnterAnEventTitleTo.
  ///
  /// In en, this message translates to:
  /// **'Enter an event title to continue.'**
  String get calendarEnterAnEventTitleTo;

  /// No description provided for @calendarSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get calendarSaveChanges;

  /// No description provided for @calendarSaveEvent.
  ///
  /// In en, this message translates to:
  /// **'Save Event'**
  String get calendarSaveEvent;

  /// No description provided for @calendarEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get calendarEditEvent;

  /// No description provided for @calendarNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get calendarNewEvent;

  /// No description provided for @calendarAddUltrasoundsShowersOrThe.
  ///
  /// In en, this message translates to:
  /// **'Add ultrasounds, showers, or the gender reveal so family knows when to celebrate.'**
  String get calendarAddUltrasoundsShowersOrThe;

  /// No description provided for @calendarNothingOnTheCalendarYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the calendar yet — check back soon.'**
  String get calendarNothingOnTheCalendarYet;

  /// No description provided for @calendarAddEventCta.
  ///
  /// In en, this message translates to:
  /// **'+ Add Event'**
  String get calendarAddEventCta;

  /// No description provided for @calendarCouldNotLoadEventsPull.
  ///
  /// In en, this message translates to:
  /// **'Could not load events. Pull to refresh or try again.'**
  String get calendarCouldNotLoadEventsPull;

  /// No description provided for @calendarWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get calendarWhen;

  /// No description provided for @calendarLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get calendarLocation;

  /// No description provided for @calendarYourRsvp.
  ///
  /// In en, this message translates to:
  /// **'Your RSVP'**
  String get calendarYourRsvp;

  /// No description provided for @calendarComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get calendarComments;

  /// No description provided for @suggestionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load suggestions: {reason}'**
  String suggestionsLoadFailed(String reason);

  /// No description provided for @calendarEventAddedToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Event added to calendar'**
  String get calendarEventAddedToCalendar;

  /// No description provided for @calendarPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Photo (optional)'**
  String get calendarPhotoOptional;

  /// No description provided for @shellYoureTheOwnerOfOne.
  ///
  /// In en, this message translates to:
  /// **'You\'re the Owner of one and a Follower of another.'**
  String get shellYoureTheOwnerOfOne;

  /// No description provided for @shellChooseWhichBabyProfileTo.
  ///
  /// In en, this message translates to:
  /// **'Choose which baby profile to view.'**
  String get shellChooseWhichBabyProfileTo;

  /// No description provided for @galleryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get galleryFavorites;

  /// No description provided for @galleryAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'All photos'**
  String get galleryAllPhotos;

  /// No description provided for @galleryRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get galleryRecentActivity;

  /// No description provided for @galleryPhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded'**
  String get galleryPhotoUploaded;

  /// No description provided for @galleryUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {reason}'**
  String galleryUploadFailed(String reason);

  /// No description provided for @galleryPhotoProcessingIsTakingLonger.
  ///
  /// In en, this message translates to:
  /// **'Photo processing is taking longer than usual. Pull to refresh the gallery.'**
  String get galleryPhotoProcessingIsTakingLonger;

  /// No description provided for @galleryThisPhotoIsNoLonger.
  ///
  /// In en, this message translates to:
  /// **'This photo is no longer available.'**
  String get galleryThisPhotoIsNoLonger;

  /// No description provided for @galleryNoCaption.
  ///
  /// In en, this message translates to:
  /// **'No caption'**
  String get galleryNoCaption;

  /// No description provided for @galleryAddYourFirstPhotoTo.
  ///
  /// In en, this message translates to:
  /// **'Add your first photo to start sharing {name}\'s journey with family.'**
  String galleryAddYourFirstPhotoTo(String name);

  /// No description provided for @galleryOnceAPhotoIsShared.
  ///
  /// In en, this message translates to:
  /// **'Once a photo is shared, it will show up here for everyone to enjoy.'**
  String get galleryOnceAPhotoIsShared;

  /// No description provided for @galleryAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'+ Add Photo'**
  String get galleryAddPhoto;

  /// No description provided for @funPredictions.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get funPredictions;

  /// No description provided for @funNoVotesYet.
  ///
  /// In en, this message translates to:
  /// **'No votes yet'**
  String get funNoVotesYet;

  /// No description provided for @funNoGuessesYet.
  ///
  /// In en, this message translates to:
  /// **'No guesses yet'**
  String get funNoGuessesYet;

  /// No description provided for @funNoGuessesYetBeThe.
  ///
  /// In en, this message translates to:
  /// **'No guesses yet - be the first!'**
  String get funNoGuessesYetBeThe;

  /// No description provided for @funNoNameIdeasWereSaved.
  ///
  /// In en, this message translates to:
  /// **'No name ideas were saved before baby arrived.'**
  String get funNoNameIdeasWereSaved;

  /// No description provided for @funSuggestANameBelowEveryone.
  ///
  /// In en, this message translates to:
  /// **'Suggest a name below — everyone gets a say.'**
  String get funSuggestANameBelowEveryone;

  /// No description provided for @funBoys.
  ///
  /// In en, this message translates to:
  /// **'Boys'**
  String get funBoys;

  /// No description provided for @funGirls.
  ///
  /// In en, this message translates to:
  /// **'Girls'**
  String get funGirls;

  /// No description provided for @funUnlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike {suggestedName}'**
  String funUnlike(String suggestedName);

  /// No description provided for @funLove.
  ///
  /// In en, this message translates to:
  /// **'Love {suggestedName}'**
  String funLove(String suggestedName);

  /// No description provided for @registryOnlyOwnersCanEditThe.
  ///
  /// In en, this message translates to:
  /// **'Only owners can edit the shipping address.'**
  String get registryOnlyOwnersCanEditThe;

  /// No description provided for @registryCouldNotLoadShippingAddress.
  ///
  /// In en, this message translates to:
  /// **'Could not load shipping address: {e}'**
  String registryCouldNotLoadShippingAddress(String e);

  /// No description provided for @registryEditRegistryItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Registry Item'**
  String get registryEditRegistryItem;

  /// No description provided for @registryAddRegistryItem.
  ///
  /// In en, this message translates to:
  /// **'Add Registry Item'**
  String get registryAddRegistryItem;

  /// No description provided for @registryIllBuyThis.
  ///
  /// In en, this message translates to:
  /// **'I\'ll buy this'**
  String get registryIllBuyThis;

  /// No description provided for @registryAddTheThingsYourBaby.
  ///
  /// In en, this message translates to:
  /// **'Add the things your baby will need so family knows what to bring.'**
  String get registryAddTheThingsYourBaby;

  /// No description provided for @registryNothingsBeenAddedToThe.
  ///
  /// In en, this message translates to:
  /// **'Nothing\'s been added to the registry yet — check back soon.'**
  String get registryNothingsBeenAddedToThe;

  /// No description provided for @registryAddItemCta.
  ///
  /// In en, this message translates to:
  /// **'+ Add Item'**
  String get registryAddItemCta;

  /// No description provided for @babyBabyCreated.
  ///
  /// In en, this message translates to:
  /// **'Baby created'**
  String get babyBabyCreated;

  /// No description provided for @babyBabyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Baby updated'**
  String get babyBabyUpdated;

  /// No description provided for @babyProfilePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'{createdLabel}; profile photo failed: {reason}'**
  String babyProfilePhotoFailed(String createdLabel, String reason);

  /// No description provided for @babyProfilePhotoSavedGalleryUpload.
  ///
  /// In en, this message translates to:
  /// **'Profile photo saved; gallery upload failed'**
  String get babyProfilePhotoSavedGalleryUpload;

  /// No description provided for @babyGalleryUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'{createdLabel}; gallery upload failed'**
  String babyGalleryUploadFailed(String createdLabel);

  /// No description provided for @babyExpectedDueDate.
  ///
  /// In en, this message translates to:
  /// **'Expected Due Date'**
  String get babyExpectedDueDate;

  /// No description provided for @babyCreateBaby.
  ///
  /// In en, this message translates to:
  /// **'Create Baby'**
  String get babyCreateBaby;

  /// No description provided for @babyExpectedDueDateCannotBe.
  ///
  /// In en, this message translates to:
  /// **'Expected due date cannot be in the past.'**
  String get babyExpectedDueDateCannotBe;

  /// No description provided for @babyProfilePhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Profile photo (optional)'**
  String get babyProfilePhotoOptional;

  /// No description provided for @babyUpdateYourBabysProfile.
  ///
  /// In en, this message translates to:
  /// **'Update your baby\'s profile'**
  String get babyUpdateYourBabysProfile;

  /// No description provided for @babyCreateYourBabysProfile.
  ///
  /// In en, this message translates to:
  /// **'Create your baby\'s profile'**
  String get babyCreateYourBabysProfile;

  /// No description provided for @babyYouCanAlwaysAddOr.
  ///
  /// In en, this message translates to:
  /// **'You can always add or change these details later.'**
  String get babyYouCanAlwaysAddOr;

  /// No description provided for @babyAlreadyBorn.
  ///
  /// In en, this message translates to:
  /// **'Already Born'**
  String get babyAlreadyBorn;

  /// No description provided for @babyGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get babyGender;

  /// No description provided for @babyTapContinueToTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Tap Continue to try again.'**
  String get babyTapContinueToTryAgain;

  /// No description provided for @babyTapCreateBabyToTry.
  ///
  /// In en, this message translates to:
  /// **'Tap Create Baby to try again.'**
  String get babyTapCreateBabyToTry;

  /// No description provided for @accountShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get accountShowPassword;

  /// No description provided for @accountHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get accountHidePassword;

  /// No description provided for @accountNoBabyProfileYouOwn.
  ///
  /// In en, this message translates to:
  /// **'No baby profile you own yet.'**
  String get accountNoBabyProfileYouOwn;

  /// No description provided for @accountExpectedDueDate.
  ///
  /// In en, this message translates to:
  /// **'Expected due date'**
  String get accountExpectedDueDate;

  /// No description provided for @accountTapToChoose.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose'**
  String get accountTapToChoose;

  /// No description provided for @accountCouldntOpenTheDownloadCopy.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the download. Copy link?'**
  String get accountCouldntOpenTheDownloadCopy;

  /// No description provided for @accountRequesting.
  ///
  /// In en, this message translates to:
  /// **'Requesting…'**
  String get accountRequesting;

  /// No description provided for @accountRequestNewExport.
  ///
  /// In en, this message translates to:
  /// **'Request new export'**
  String get accountRequestNewExport;

  /// No description provided for @accountPhotosSquished.
  ///
  /// In en, this message translates to:
  /// **'Photos Squished'**
  String get accountPhotosSquished;

  /// No description provided for @accountEventsAttended.
  ///
  /// In en, this message translates to:
  /// **'Events Attended'**
  String get accountEventsAttended;

  /// No description provided for @accountItemsBought.
  ///
  /// In en, this message translates to:
  /// **'Items Bought'**
  String get accountItemsBought;

  /// No description provided for @accountPendingInvite.
  ///
  /// In en, this message translates to:
  /// **'Pending invite'**
  String get accountPendingInvite;

  /// No description provided for @accountAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted · {formatted}'**
  String accountAccepted(String formatted);

  /// No description provided for @accountInviteEmailQueued.
  ///
  /// In en, this message translates to:
  /// **'Invite email queued'**
  String get accountInviteEmailQueued;

  /// No description provided for @announcementFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get announcementFamily;

  /// No description provided for @announcementOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get announcementOptional;

  /// No description provided for @announcementSaveAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Save Announcement'**
  String get announcementSaveAnnouncement;

  /// No description provided for @announcementOurBabyAnnouncementIsHere.
  ///
  /// In en, this message translates to:
  /// **'Our baby announcement is here!'**
  String get announcementOurBabyAnnouncementIsHere;

  /// No description provided for @announcementMeet.
  ///
  /// In en, this message translates to:
  /// **'Meet {name}!'**
  String announcementMeet(String name);

  /// No description provided for @announcementBabyAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Baby announcement'**
  String get announcementBabyAnnouncement;

  /// No description provided for @onboardingWeCouldntLoadYourBaby.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your baby profile. Check your connection and try again.'**
  String get onboardingWeCouldntLoadYourBaby;

  /// No description provided for @onboardingAtLeast6CharactersWith.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters, with a number or symbol.'**
  String get onboardingAtLeast6CharactersWith;

  /// No description provided for @onboardingWePulledInYourDetails.
  ///
  /// In en, this message translates to:
  /// **'We pulled in your details. Add a photo so family knows who\'s who.'**
  String get onboardingWePulledInYourDetails;

  /// No description provided for @onboardingCompleteYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get onboardingCompleteYourProfile;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingCouldNotSendVerificationEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not send verification email. Please try again.'**
  String get onboardingCouldNotSendVerificationEmail;

  /// No description provided for @onboardingYourEmail.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get onboardingYourEmail;

  /// No description provided for @onboardingTheOwner.
  ///
  /// In en, this message translates to:
  /// **'The owner'**
  String get onboardingTheOwner;

  /// No description provided for @onboardingWelcomeToSCircle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {babyName}\'s circle'**
  String onboardingWelcomeToSCircle(String babyName);

  /// No description provided for @onboardingAddedYouAs.
  ///
  /// In en, this message translates to:
  /// **'{inviter} added you as'**
  String onboardingAddedYouAs(String inviter);

  /// No description provided for @onboardingThisIsHowYoullAppear.
  ///
  /// In en, this message translates to:
  /// **'This is how you\'ll appear to the rest of the family. {inviter} can update it anytime from their side.'**
  String onboardingThisIsHowYoullAppear(String inviter);

  /// No description provided for @onboardingOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get onboardingOpen;

  /// No description provided for @onboardingAcceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept Invitation'**
  String get onboardingAcceptInvitation;

  /// No description provided for @onboardingReliveEveryMilestoneInThe.
  ///
  /// In en, this message translates to:
  /// **'Relive every milestone in the Gallery'**
  String get onboardingReliveEveryMilestoneInThe;

  /// No description provided for @onboardingBabyIsAlreadyHereSee.
  ///
  /// In en, this message translates to:
  /// **'Baby is already here. See the first photos and everything since.'**
  String get onboardingBabyIsAlreadyHereSee;

  /// No description provided for @onboardingVoteGuessInFamilyFun.
  ///
  /// In en, this message translates to:
  /// **'Vote & guess in Family Fun'**
  String get onboardingVoteGuessInFamilyFun;

  /// No description provided for @onboardingSuggestNamesVoteOnFavorites.
  ///
  /// In en, this message translates to:
  /// **'Suggest names, vote on favorites, and guess the birthdate. Results reveal once baby arrives.'**
  String get onboardingSuggestNamesVoteOnFavorites;

  /// No description provided for @onboardingWelcomeYoureIn.
  ///
  /// In en, this message translates to:
  /// **'Welcome, you\'re in!'**
  String get onboardingWelcomeYoureIn;

  /// No description provided for @onboardingAPrivateSpaceJustFor.
  ///
  /// In en, this message translates to:
  /// **'A private space just for the family and friends closest to your circle.'**
  String get onboardingAPrivateSpaceJustFor;

  /// No description provided for @onboardingSquishPhotosLeaveComments.
  ///
  /// In en, this message translates to:
  /// **'Squish photos & leave comments'**
  String get onboardingSquishPhotosLeaveComments;

  /// No description provided for @onboardingTapTheHeartToSquish.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart to \"squish\" any photo the family shares.'**
  String get onboardingTapTheHeartToSquish;

  /// No description provided for @onboardingNeverMissWhatsNext.
  ///
  /// In en, this message translates to:
  /// **'Never miss what\'s next'**
  String get onboardingNeverMissWhatsNext;

  /// No description provided for @onboardingSeeUpcomingEventsLikeGender.
  ///
  /// In en, this message translates to:
  /// **'See upcoming events, like gender reveals and baby showers, and RSVP right from the app.'**
  String get onboardingSeeUpcomingEventsLikeGender;

  /// No description provided for @onboardingGetUpdatesYourWay.
  ///
  /// In en, this message translates to:
  /// **'Get updates your way'**
  String get onboardingGetUpdatesYourWay;

  /// No description provided for @onboardingChooseHowOftenYouHear.
  ///
  /// In en, this message translates to:
  /// **'Choose how often you hear from us: real-time, daily, or a weekly digest. You can change this anytime.'**
  String get onboardingChooseHowOftenYouHear;

  /// No description provided for @onboardingFollowerGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingFollowerGetStarted;

  /// No description provided for @onboardingAcceptJoinAsOwner.
  ///
  /// In en, this message translates to:
  /// **'Accept & Join as Owner'**
  String get onboardingAcceptJoinAsOwner;

  /// No description provided for @onboardingYourCoParent.
  ///
  /// In en, this message translates to:
  /// **'your co-parent'**
  String get onboardingYourCoParent;

  /// No description provided for @onboardingSignInToAcceptYour.
  ///
  /// In en, this message translates to:
  /// **'Sign in to accept your invitation and continue.'**
  String get onboardingSignInToAcceptYour;

  /// No description provided for @onboardingSignInToContinueSetting.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue setting up your family space.'**
  String get onboardingSignInToContinueSetting;

  /// No description provided for @onboardingGoogleSignInIsNot.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In is not configured for this Android build yet. Use email/password, or enable Google in Firebase for lanonna-dev.'**
  String get onboardingGoogleSignInIsNot;

  /// No description provided for @onboardingWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get onboardingWelcomeBack;

  /// No description provided for @onboardingAiSuggestedByStageAnd.
  ///
  /// In en, this message translates to:
  /// **'AI-suggested by stage and age'**
  String get onboardingAiSuggestedByStageAnd;

  /// No description provided for @onboardingAddYourFirstMoment.
  ///
  /// In en, this message translates to:
  /// **'Add your first moment'**
  String get onboardingAddYourFirstMoment;

  /// No description provided for @onboardingTotallyOptionalButItHelps.
  ///
  /// In en, this message translates to:
  /// **'Totally optional, but it helps family feel like there\'s already something here.'**
  String get onboardingTotallyOptionalButItHelps;

  /// No description provided for @onboardingSeedsTheVoteInFamily.
  ///
  /// In en, this message translates to:
  /// **'Seeds the vote in Family Fun'**
  String get onboardingSeedsTheVoteInFamily;

  /// No description provided for @onboardingFromYourCameraOrLibrary.
  ///
  /// In en, this message translates to:
  /// **'From your camera or library'**
  String get onboardingFromYourCameraOrLibrary;

  /// No description provided for @onboardingYourRelationshipToBaby.
  ///
  /// In en, this message translates to:
  /// **'Your relationship to baby'**
  String get onboardingYourRelationshipToBaby;

  /// No description provided for @invitationsAlreadyOnTheFamily.
  ///
  /// In en, this message translates to:
  /// **'Already on the family'**
  String get invitationsAlreadyOnTheFamily;

  /// No description provided for @invitationsInvitationAlreadyPending.
  ///
  /// In en, this message translates to:
  /// **'Invitation already pending'**
  String get invitationsInvitationAlreadyPending;

  /// No description provided for @invitationsAddAnotherPerson.
  ///
  /// In en, this message translates to:
  /// **'Add another person'**
  String get invitationsAddAnotherPerson;

  /// No description provided for @invitationsInviteFamilyFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite family & friends'**
  String get invitationsInviteFamilyFriends;

  /// No description provided for @invitationsAddThePeopleYouWant.
  ///
  /// In en, this message translates to:
  /// **'Add the people you want to share this with. You can always invite more later.'**
  String get invitationsAddThePeopleYouWant;

  /// No description provided for @invitationsWellSendEachPersonA.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send each person a private link. It expires in 14 days.'**
  String get invitationsWellSendEachPersonA;

  /// No description provided for @invitationsAFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'A family member'**
  String get invitationsAFamilyMember;

  /// No description provided for @invitationsYoureAlreadyAMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re already a member'**
  String get invitationsYoureAlreadyAMember;

  /// No description provided for @invitationsAsACoOwnerYoull.
  ///
  /// In en, this message translates to:
  /// **'As a co-owner, you\'ll have full access to edit, invite, and manage, just like the person who invited you.'**
  String get invitationsAsACoOwnerYoull;

  /// No description provided for @invitationsAPrivateSpaceJustFor.
  ///
  /// In en, this message translates to:
  /// **'A private space just for family & friends. Nothing here is public.'**
  String get invitationsAPrivateSpaceJustFor;

  /// No description provided for @invitationsInvitationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invitation unavailable'**
  String get invitationsInvitationUnavailable;

  /// No description provided for @homeInvitesNotifiedWithLine.
  ///
  /// In en, this message translates to:
  /// **'{line}. Everyone you\'ve invited has been notified.'**
  String homeInvitesNotifiedWithLine(String line);

  /// No description provided for @invitationsInvitedYouToCoOwn.
  ///
  /// In en, this message translates to:
  /// **'{inviter} invited you to co-own'**
  String invitationsInvitedYouToCoOwn(String inviter);

  /// No description provided for @invitationsInvitedYouToFollow.
  ///
  /// In en, this message translates to:
  /// **'{inviter} invited you to follow'**
  String invitationsInvitedYouToFollow(String inviter);

  /// No description provided for @eventRsvpGoingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} going'**
  String eventRsvpGoingCount(int count);

  /// No description provided for @eventRsvpMaybeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} maybe'**
  String eventRsvpMaybeCount(int count);

  /// No description provided for @errorAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'This account was deleted.'**
  String get errorAccountDeleted;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is busy right now. Please try again in a moment.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Some details aren\'t valid. Check them and try again.'**
  String get errorInvalidRequest;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available.'**
  String get errorNotFound;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errorForbidden;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'This changed while you were working. Refresh and try again.'**
  String get errorConflict;

  /// No description provided for @errorUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorUnauthenticated;

  /// No description provided for @errorAppCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'This app couldn\'t be verified. Update the app and try again.'**
  String get errorAppCheckFailed;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorNotMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re not a member of this baby profile.'**
  String get errorNotMember;

  /// No description provided for @errorTargetNotMember.
  ///
  /// In en, this message translates to:
  /// **'That person is no longer a member of this baby profile.'**
  String get errorTargetNotMember;

  /// No description provided for @errorLastOwner.
  ///
  /// In en, this message translates to:
  /// **'You can\'t remove the last owner of this baby profile.'**
  String get errorLastOwner;

  /// No description provided for @errorCannotDeleteSharedBaby.
  ///
  /// In en, this message translates to:
  /// **'This baby profile has a co-owner. Leave the profile instead of deleting it.'**
  String get errorCannotDeleteSharedBaby;

  /// No description provided for @errorUseLeaveProfile.
  ///
  /// In en, this message translates to:
  /// **'To remove yourself, use Leave profile.'**
  String get errorUseLeaveProfile;

  /// No description provided for @errorEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Verify your email before finishing setup.'**
  String get errorEmailNotVerified;

  /// No description provided for @errorBabyProfileRequired.
  ///
  /// In en, this message translates to:
  /// **'Create a baby profile before finishing setup.'**
  String get errorBabyProfileRequired;

  /// No description provided for @errorProfileIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile before finishing setup.'**
  String get errorProfileIncomplete;

  /// No description provided for @errorInvalidBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date of birth.'**
  String get errorInvalidBirthDate;

  /// No description provided for @errorTextTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep this to {maxLength} characters or fewer.'**
  String errorTextTooLong(int maxLength);

  /// No description provided for @errorInvalidBirthTime.
  ///
  /// In en, this message translates to:
  /// **'Enter the birth time as HH:MM (24-hour).'**
  String get errorInvalidBirthTime;

  /// No description provided for @errorCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a comment first.'**
  String get errorCommentRequired;

  /// No description provided for @errorUnsupportedMediaType.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get errorUnsupportedMediaType;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large.'**
  String get errorFileTooLarge;

  /// No description provided for @errorFunClosed.
  ///
  /// In en, this message translates to:
  /// **'Fun is closed — baby has arrived!'**
  String get errorFunClosed;

  /// No description provided for @errorPredictionsClosed.
  ///
  /// In en, this message translates to:
  /// **'Predictions are closed — baby has arrived!'**
  String get errorPredictionsClosed;

  /// No description provided for @errorDuplicateNameSuggestion.
  ///
  /// In en, this message translates to:
  /// **'That name is already on the list.'**
  String get errorDuplicateNameSuggestion;

  /// No description provided for @errorNameAlreadySuggested.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already suggested a name for this gender.'**
  String get errorNameAlreadySuggested;

  /// No description provided for @errorAlreadyOnRegistry.
  ///
  /// In en, this message translates to:
  /// **'This is already on the registry.'**
  String get errorAlreadyOnRegistry;

  /// No description provided for @errorRegistryItemPurchased.
  ///
  /// In en, this message translates to:
  /// **'This gift has already been purchased.'**
  String get errorRegistryItemPurchased;

  /// No description provided for @errorShippingAddressIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Add the street address, city, postal code and country.'**
  String get errorShippingAddressIncomplete;

  /// No description provided for @errorAlreadyOnCalendar.
  ///
  /// In en, this message translates to:
  /// **'This is already on the calendar.'**
  String get errorAlreadyOnCalendar;

  /// No description provided for @errorEventEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end time must be at or after the start time.'**
  String get errorEventEndBeforeStart;

  /// No description provided for @errorEmailQueueFailed.
  ///
  /// In en, this message translates to:
  /// **'The invite was saved, but its email couldn\'t be sent. Use Resend on Manage followers.'**
  String get errorEmailQueueFailed;

  /// No description provided for @errorExportQueueFailed.
  ///
  /// In en, this message translates to:
  /// **'The export couldn\'t be started. Please try again in a few minutes.'**
  String get errorExportQueueFailed;

  /// No description provided for @errorPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Photo exceeds the maximum size ({megabytes} MB).'**
  String errorPhotoTooLarge(String megabytes);

  /// No description provided for @photoSourceHint.
  ///
  /// In en, this message translates to:
  /// **'JPEG or PNG, up to {megabytes}MB'**
  String photoSourceHint(String megabytes);

  /// No description provided for @inviteErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired. Ask the family to send a new invite.'**
  String get inviteErrorExpired;

  /// No description provided for @inviteErrorRevoked.
  ///
  /// In en, this message translates to:
  /// **'This invitation was revoked. Ask the family to send a new invite.'**
  String get inviteErrorRevoked;

  /// No description provided for @inviteErrorAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already used. Sign in with the account that accepted it.'**
  String get inviteErrorAlreadyUsed;

  /// No description provided for @inviteErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This invitation link is invalid or was revoked.'**
  String get inviteErrorNotFound;

  /// No description provided for @inviteErrorMaxOwners.
  ///
  /// In en, this message translates to:
  /// **'This baby already has the maximum number of owners.'**
  String get inviteErrorMaxOwners;

  /// No description provided for @inviteErrorEmailMismatch.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the email address that received the invitation.'**
  String get inviteErrorEmailMismatch;

  /// No description provided for @inviteErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not accept this invitation. Please try again.'**
  String get inviteErrorGeneric;

  /// No description provided for @inviteErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to open this invitation.'**
  String get inviteErrorOffline;

  /// No description provided for @inviteErrorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this invitation. Try again.'**
  String get inviteErrorLoadFailed;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get validationPasswordTooShort;

  /// No description provided for @validationPasswordNeedsSymbol.
  ///
  /// In en, this message translates to:
  /// **'Include a number or symbol'**
  String get validationPasswordNeedsSymbol;

  /// No description provided for @validationDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get validationDisplayNameRequired;

  /// No description provided for @validationDisplayNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Display name is too long'**
  String get validationDisplayNameTooLong;

  /// No description provided for @validationFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get validationFirstNameRequired;

  /// No description provided for @validationLastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get validationLastNameRequired;

  /// No description provided for @validationPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get validationPhoneInvalid;

  /// No description provided for @validationTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms to continue'**
  String get validationTermsRequired;

  /// No description provided for @validationRelationshipRequired.
  ///
  /// In en, this message translates to:
  /// **'Select your relationship to baby'**
  String get validationRelationshipRequired;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validationNameRequired;

  /// No description provided for @validationItemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Item name is required'**
  String get validationItemNameRequired;

  /// No description provided for @validationStreetRequired.
  ///
  /// In en, this message translates to:
  /// **'Street address is required'**
  String get validationStreetRequired;

  /// No description provided for @validationCityRequired.
  ///
  /// In en, this message translates to:
  /// **'City is required'**
  String get validationCityRequired;

  /// No description provided for @validationPostalCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Zip / Postal code is required'**
  String get validationPostalCodeRequired;

  /// No description provided for @validationCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a country'**
  String get validationCountryRequired;

  /// No description provided for @validationUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid link, e.g. https://…'**
  String get validationUrlInvalid;

  /// No description provided for @authErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes, then try Resend email again.'**
  String get authErrorTooManyAttempts;

  /// No description provided for @authErrorVerifyLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This verification link has expired or was already used. Tap Resend email for a new link.'**
  String get authErrorVerifyLinkExpired;

  /// No description provided for @authErrorVerifyLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your email from this link. Try Resend email or open the newest message in your inbox.'**
  String get authErrorVerifyLinkFailed;

  /// No description provided for @linkOpenFailedCopy.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link. Copy link?'**
  String get linkOpenFailedCopy;

  /// No description provided for @linkCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get linkCopyAction;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @storeOpenFailedCopy.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the store. Copy link?'**
  String get storeOpenFailedCopy;

  /// No description provided for @inviteBabyAlreadyHere.
  ///
  /// In en, this message translates to:
  /// **'Already here'**
  String get inviteBabyAlreadyHere;

  /// No description provided for @inviteBabyOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get inviteBabyOnTheWay;

  /// No description provided for @inviteBabyArriving.
  ///
  /// In en, this message translates to:
  /// **'Arriving {date}'**
  String inviteBabyArriving(String date);

  /// No description provided for @lifecycleBornOn.
  ///
  /// In en, this message translates to:
  /// **'Born {date}'**
  String lifecycleBornOn(String date);

  /// No description provided for @lifecycleDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String lifecycleDueOn(String date);

  /// No description provided for @ownerCarouselTitle1.
  ///
  /// In en, this message translates to:
  /// **'Your baby\'s story, in one private place'**
  String get ownerCarouselTitle1;

  /// No description provided for @ownerCarouselBody1.
  ///
  /// In en, this message translates to:
  /// **'Photos, updates, and everything in between, visible only to the people you invite.'**
  String get ownerCarouselBody1;

  /// No description provided for @ownerCarouselTitle2.
  ///
  /// In en, this message translates to:
  /// **'Everyone gets to feel close'**
  String get ownerCarouselTitle2;

  /// No description provided for @ownerCarouselBody2.
  ///
  /// In en, this message translates to:
  /// **'Grandparents, aunts, uncles, and friends can follow along, no matter how far away they live.'**
  String get ownerCarouselBody2;

  /// No description provided for @ownerCarouselTitle3.
  ///
  /// In en, this message translates to:
  /// **'Celebrate every milestone together'**
  String get ownerCarouselTitle3;

  /// No description provided for @ownerCarouselBody3.
  ///
  /// In en, this message translates to:
  /// **'Calendar events, a shared registry, and fun ways to mark the big days.'**
  String get ownerCarouselBody3;

  /// No description provided for @ownerCarouselTitle4.
  ///
  /// In en, this message translates to:
  /// **'Never lose a moment'**
  String get ownerCarouselTitle4;

  /// No description provided for @ownerCarouselBody4.
  ///
  /// In en, this message translates to:
  /// **'Every photo and comment, saved in one safe place, for good.'**
  String get ownerCarouselBody4;

  /// No description provided for @relativeTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get relativeTimeJustNow;

  /// No description provided for @relativeTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get relativeTimeYesterday;

  /// No description provided for @relativeTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String relativeTimeMinutesAgo(int count);

  /// No description provided for @relativeTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String relativeTimeHoursAgo(int count);

  /// No description provided for @relativeTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String relativeTimeDaysAgo(int count);

  /// No description provided for @calendarWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Su'**
  String get calendarWeekdaySun;

  /// No description provided for @calendarWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mo'**
  String get calendarWeekdayMon;

  /// No description provided for @calendarWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tu'**
  String get calendarWeekdayTue;

  /// No description provided for @calendarWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'We'**
  String get calendarWeekdayWed;

  /// No description provided for @calendarWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Th'**
  String get calendarWeekdayThu;

  /// No description provided for @calendarWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fr'**
  String get calendarWeekdayFri;

  /// No description provided for @calendarWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sa'**
  String get calendarWeekdaySat;

  /// No description provided for @onboardingCompleteProfileSubtext.
  ///
  /// In en, this message translates to:
  /// **'Add your name and photo so family knows who\'s who.'**
  String get onboardingCompleteProfileSubtext;

  /// No description provided for @activityEmptyDefault.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet - activity will show up here.'**
  String get activityEmptyDefault;

  /// No description provided for @photoAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get photoAddAction;

  /// No description provided for @photoChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get photoChangeAction;

  /// No description provided for @photoUploadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get photoUploadingLabel;

  /// No description provided for @babyNameDefault.
  ///
  /// In en, this message translates to:
  /// **'Baby'**
  String get babyNameDefault;

  /// No description provided for @personNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Family member'**
  String get personNameFallback;

  /// No description provided for @relationshipWife.
  ///
  /// In en, this message translates to:
  /// **'Wife'**
  String get relationshipWife;

  /// No description provided for @relationshipHusband.
  ///
  /// In en, this message translates to:
  /// **'Husband'**
  String get relationshipHusband;

  /// No description provided for @relationshipMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get relationshipMother;

  /// No description provided for @relationshipFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get relationshipFather;

  /// No description provided for @relationshipGrandma.
  ///
  /// In en, this message translates to:
  /// **'Grandma'**
  String get relationshipGrandma;

  /// No description provided for @relationshipGrandpa.
  ///
  /// In en, this message translates to:
  /// **'Grandpa'**
  String get relationshipGrandpa;

  /// No description provided for @relationshipAunt.
  ///
  /// In en, this message translates to:
  /// **'Aunt'**
  String get relationshipAunt;

  /// No description provided for @relationshipUncle.
  ///
  /// In en, this message translates to:
  /// **'Uncle'**
  String get relationshipUncle;

  /// No description provided for @relationshipGodmother.
  ///
  /// In en, this message translates to:
  /// **'Godmother'**
  String get relationshipGodmother;

  /// No description provided for @relationshipGodfather.
  ///
  /// In en, this message translates to:
  /// **'Godfather'**
  String get relationshipGodfather;

  /// No description provided for @relationshipFamilyFriend.
  ///
  /// In en, this message translates to:
  /// **'Family Friend'**
  String get relationshipFamilyFriend;

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} shared a photo'**
  String activityPhotoShared(String actor);

  /// Activity feed row. {actor} is the member's display name (bold). {caption} is the photo caption.
  ///
  /// In en, this message translates to:
  /// **'{actor} shared \"{caption}\"'**
  String activityPhotoSharedCaption(String actor, String caption);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} squished a photo'**
  String activityPhotoSquish(String actor);

  /// Activity feed row. {actor} is the member's display name (bold). {caption} is the photo caption.
  ///
  /// In en, this message translates to:
  /// **'{actor} squished \"{caption}\"'**
  String activityPhotoSquishCaption(String actor, String caption);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on a photo'**
  String activityPhotoComment(String actor);

  /// Activity feed row. {actor} is the member's display name (bold). {caption} is the photo caption.
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on \"{caption}\"'**
  String activityPhotoCommentCaption(String actor, String caption);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} added \"{item}\" to the registry'**
  String activityRegistryItemAdded(String actor, String item);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} marked \"{item}\" as purchased'**
  String activityRegistryPurchased(String actor, String item);

  /// Activity feed row for a follower's registry claim; the buyer stays anonymous.
  ///
  /// In en, this message translates to:
  /// **'Someone is buying \"{item}\"'**
  String activityRegistryClaimed(String item);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} added \"{title}\" to the calendar'**
  String activityEventCreated(String actor, String title);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} suggested the name \"{name}\"'**
  String activityNameSuggested(String actor, String name);

  /// Activity feed row. {actor} is the member's display name (bold). {gender} is the API gender value.
  ///
  /// In en, this message translates to:
  /// **'{gender, select, male{{actor} guessed boy} female{{actor} guessed girl} other{{actor} made a gender guess}}'**
  String activityGenderVoteCast(String actor, String gender);

  /// Activity feed row. {baby} is the baby's name.
  ///
  /// In en, this message translates to:
  /// **'{baby} has arrived!'**
  String activityBabyArrived(String baby);

  /// Activity feed row. {actor} is the member's display name (bold). {member} is the removed member's name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} removed {member} from the family'**
  String activityMemberRemoved(String actor, String member);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} removed a member from the family'**
  String activityMemberRemovedUnnamed(String actor);

  /// Activity feed row. {actor} is the member's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} left the family'**
  String activityMemberLeft(String actor);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} shared a new photo'**
  String inboxPhotoShared(String actor);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} squished your photo'**
  String inboxPhotoSquished(String actor);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on your photo'**
  String inboxPhotoCommented(String actor);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} added \"{title}\" to the calendar'**
  String inboxEventCreated(String actor, String title);

  /// Inbox notification row. {actor} is the sender's display name (bold). {status} is the API RSVP value.
  ///
  /// In en, this message translates to:
  /// **'{status, select, going{{actor} is going to \"{title}\"} maybe{{actor} might go to \"{title}\"} cant_go{{actor} can\'t make it to \"{title}\"} other{{actor} replied to \"{title}\"}}'**
  String inboxEventRsvp(String actor, String title, String status);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on \"{title}\"'**
  String inboxEventCommented(String actor, String title);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} marked \"{item}\" as purchased'**
  String inboxRegistryPurchased(String actor, String item);

  /// Inbox notification row. {actor} is the sender's display name (bold).
  ///
  /// In en, this message translates to:
  /// **'{actor} is buying \"{item}\"'**
  String inboxRegistryBuying(String actor, String item);

  /// Inbox notification row. {actor} is the sender's display name (bold). {baby} is the baby's name.
  ///
  /// In en, this message translates to:
  /// **'{actor} joined {baby}'**
  String inboxInviteAccepted(String actor, String baby);

  /// Inbox notification row. {baby} is the baby's name.
  ///
  /// In en, this message translates to:
  /// **'{baby} has arrived! See the announcement.'**
  String inboxBabyArrived(String baby);

  /// Batch invite alert for rows the server skipped because of the owner limit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 co-owner invite was not sent: this baby profile already has the most owners it can have, counting pending co-owner invites.} other{{count} co-owner invites were not sent: this baby profile already has the most owners it can have, counting pending co-owner invites.}}'**
  String batchInviteMaxOwnersSkipped(int count);
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
