# Firebase Auth email templates

HTML + subject lines for **Firebase Authentication** lifecycle mail (email verification and password reset). These are **not** sent via Mailjet — see [`packages/email-templates`](../email-templates) for product invites.

## Placeholders (Firebase)

| Placeholder | Meaning |
|-------------|---------|
| `%LINK%` | Verification / action URL (use in `href` for a tappable button) |
| `%EMAIL%` | Recipient email |
| `%APP_NAME%` | OAuth brand **public-facing name** (`applicationTitle`). Set to **La Nonna** with `scripts/configure-firebase-auth-email-project.sh`. This is not the GCP project name and not the Firebase `displayName`. |
| `%DISPLAY_NAME%` | User display name when available |

## Apply to a Firebase project

From repo root (requires `gcloud` auth with permission to update Identity Platform config):

```bash
bash scripts/configure-firebase-auth-email-project.sh apply
bash scripts/configure-firebase-auth-email-project.sh check
GCP_PROJECT_ID=lanonna-dev bash scripts/sync-firebase-auth-templates.sh apply
GCP_PROJECT_ID=lanonna-dev bash scripts/sync-firebase-auth-templates.sh check-remote
```

`sync-firebase-auth-templates.sh check` validates the files in this folder and does not call Google. `check-remote` and `apply` read the live Identity Toolkit config, patch only drifted fields, and fail if the result still does not match. Re-running apply when nothing drifted is a no-op.

`configure-firebase-auth-email-project.sh` sets the ADC quota project, the GCP project name, the Firebase `displayName`, and the OAuth brand `applicationTitle` to **La Nonna**. If no brand exists yet, enable Google sign-in in the Firebase console (public-facing name **La Nonna**). Do not create a brand with the IAP brands API; those brands are internal-only and can break public Google sign-in.

If `apply` returns `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`, Firebase has locked subject/body updates. File support using [`scripts/firebase-auth-template-support-request.md`](../../scripts/firebase-auth-template-support-request.md). With the public-facing name set, the default subject “Verify your email for %APP_NAME%” already says La Nonna.

## Console

- **Public-facing name:** Firebase → Authentication → Sign-in method → Google, or Project settings → General. Confirm it reads **La Nonna** after `configure-firebase-auth-email-project.sh check`.
- **Custom sender domain** (SPF/DKIM): deferred — still `noreply@…firebaseapp.com` until configured.
