# Firebase Auth email templates

HTML + subject lines for **Firebase Authentication** lifecycle mail (email verification, etc.). These are **not** sent via Mailjet — see [`packages/email-templates`](../email-templates) for product invites.

## Placeholders (Firebase)

| Placeholder | Meaning |
|-------------|---------|
| `%LINK%` | Verification / action URL (use in `href` for a tappable button) |
| `%EMAIL%` | Recipient email |
| `%APP_NAME%` | GCP project **public display name** (set to **La Nonna** in Console) |
| `%DISPLAY_NAME%` | User display name when available |

## Apply to a Firebase project

From repo root (requires `gcloud` auth with permission to update Identity Platform config):

```bash
GCP_PROJECT_ID=lanonna-dev bash scripts/sync-firebase-auth-templates.sh apply
```

CI runs `check` only (validates files; does not call Google APIs).

If `apply` returns `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`, paste `verify_email.html` / subject into [Firebase Console → Authentication → Templates → Email address verification](https://console.firebase.google.com/project/lanonna-dev/authentication/emails) (some projects block API template writes).

## Console

- **Public-facing name:** Google Cloud Console → project settings → rename to **La Nonna** (improves `%APP_NAME%` and default copy).
- **Custom sender domain** (SPF/DKIM): deferred — still `noreply@…firebaseapp.com` until configured.
