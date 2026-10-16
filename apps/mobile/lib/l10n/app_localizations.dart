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

  String get actionRetry;

  String get babyNameFallback;

  String get notificationsInboxTitle;

  String get notificationsMarkAllRead;

  String get notificationsInboxEmptyTitle;

  String get notificationsInboxEmptyMessage;

  String get inboxNotificationFallbackTitle;

  String get accountDigestFrequency;

  String get homeBornActivityEmpty;

  String get calendarPastEventsTitle;

  String get calendarPastEventsSubtitle;

  String get calendarPastEventsEmpty;

  String get calendarLoadMore;

  String get registrySortPriorityHighFirst;

  String get registrySortPriorityLowFirst;
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
