# Shared packages

Optional libraries used by more than one service or app.

| Package | Purpose |
|---------|---------|
| [email-templates](email-templates/) | Versioned invite and notification HTML for Mailjet |
| [lanonna_activity_copy](lanonna_activity_copy/) | Shared feed vocabulary for API + worker: activity event types, notification kinds, display param keys, English push copy (`push_copy`) and diagnostic activity summaries. The app mirrors the types, kinds and keys (`test_feed_vocabulary_parity.py`) and renders all in-app text from ARB |

Add a shared server module here when `api` and `worker` share a language runtime.
