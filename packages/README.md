# Shared packages

Optional libraries used by more than one service or app.

| Package | Purpose |
|---------|---------|
| [email-templates](email-templates/) | Versioned invite and notification HTML for Mailjet |
| [lanonna_activity_copy](lanonna_activity_copy/) | Shared activity feed summary strings (`photo_shared`, squish, comment) for API + worker |

Add a shared server module here when `api` and `worker` share a language runtime.
