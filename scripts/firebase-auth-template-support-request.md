# Firebase Support — manual auth email template apply

Use when `sync-firebase-auth-templates.sh apply` reports `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` for **subject** or **body** (Firebase abuse-prevention lock; not fixable via GCP IAM/org policy).

1. Open [Firebase support](https://firebase.google.com/support/troubleshooter/contact) (project: **lanonna-dev**).
2. Request **engineering escalation** to apply the **Email address verification** template from this repo:
   - **Subject:** contents of `packages/firebase-auth-email-templates/verify_email.subject`
   - **HTML body:** contents of `packages/firebase-auth-email-templates/verify_email.html`
3. Note that **sender display name** `La Nonna` and **Firebase display name** `La Nonna` are already set via CLI.

Until Google applies the template, verification emails use the default Firebase HTML (link is still clickable; branding is limited).
