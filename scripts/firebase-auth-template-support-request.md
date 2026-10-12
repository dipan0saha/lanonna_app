# Firebase Support — manual auth email template apply

Use this only when `bash scripts/sync-firebase-auth-templates.sh apply` reports `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` for **subject** or **body**. That error is a Firebase abuse-prevention lock. It is not fixed by GCP IAM or org policy. Sender display name and the public-facing name are updated by the repo scripts and usually are not locked.

**What the scripts already set (re-check before opening a case):**

```bash
bash scripts/configure-firebase-auth-email-project.sh check
bash scripts/sync-firebase-auth-templates.sh check-remote
```

- GCP project name, Firebase `displayName`, and OAuth brand `applicationTitle` (**public-facing name**, which fills `%APP_NAME%`): **La Nonna**
- Sender display name: **La Nonna**

`%APP_NAME%` is **not** the GCP project name. A subject that still says `project-1008830071001` means the public-facing name was never set. Fix that with the configure script (or by enabling Google sign-in in the console) before filing this request. Do not create an OAuth brand with the IAP brands API.

**Once the lock is the only remaining failure:**

1. Open [Firebase support](https://firebase.google.com/support/troubleshooter/contact) for project **lanonna-dev** (number `1008830071001`).
2. Ask for an engineering escalation to apply both templates from this repo:
   - Email address verification: `packages/firebase-auth-email-templates/verify_email.subject` and `verify_email.html`
   - Password reset: `packages/firebase-auth-email-templates/reset_password.subject` and `reset_password.html`
3. Say that sender display name **La Nonna** and public-facing name **La Nonna** are already set, and that Identity Toolkit `PATCH` of `notification.sendEmail.callback` subject and body returns `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`.

After Google confirms, re-run `bash scripts/sync-firebase-auth-templates.sh apply` and `check-remote`, then send a new verification email and a password-reset email.

Until the HTML is applied, default Firebase bodies remain. With the public-facing name set, the default subjects read “Verify your email for La Nonna” and “Reset your password for La Nonna”.

Custom delivery through the Admin SDK plus Mailjet is not implemented. Custom sender domain (SPF/DKIM) stays deferred.
