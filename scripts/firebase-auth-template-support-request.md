# Firebase Support — manual auth email template apply

## TODO (deferred) — [#390](https://github.com/dipan0saha/nonna_app/issues/390) / FR-AUTH-002

**Status (2026-10-04):** Blocked on Google. CLI apply and Firebase Console **Save** both fail for verify-email **subject** and **HTML body** (`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`). Sender display name **La Nonna** and Firebase/GCP display name **La Nonna** are already set via `scripts/configure-firebase-auth-email-project.sh`.

**When ready:** Open a Firebase Support case (steps below), request engineering escalation to apply `packages/firebase-auth-email-templates/verify_email.subject` and `verify_email.html` on **lanonna-dev**. After Google confirms, re-run `sync-firebase-auth-templates.sh apply` to verify, then sign-up QA per `emulator_testing/README.md` (email verification section).

**Alternatives if support is slow:** Custom delivery via Admin SDK `generate_email_verification_link` + Mailjet (not implemented).

---

Use when `sync-firebase-auth-templates.sh apply` reports `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` for **subject** or **body** (Firebase abuse-prevention lock; not fixable via GCP IAM/org policy).

1. Open [Firebase support](https://firebase.google.com/support/troubleshooter/contact) (project: **lanonna-dev**).
2. Request **engineering escalation** to apply the **Email address verification** template from this repo:
   - **Subject:** contents of `packages/firebase-auth-email-templates/verify_email.subject`
   - **HTML body:** contents of `packages/firebase-auth-email-templates/verify_email.html`
3. Note that **sender display name** `La Nonna` and **Firebase display name** `La Nonna` are already set via CLI.

Until Google applies the template, verification emails use the default Firebase HTML (link is still clickable; branding is limited).
