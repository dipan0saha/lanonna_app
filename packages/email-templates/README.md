# Email templates

Product transactional mail (invites, reminders) — rendered by the worker and sent via **Mailjet**.

- Keep templates in this folder (HTML + plain-text parts).
- Auth lifecycle mail (verification, password reset) stays on **Firebase Auth**, not Mailjet.

Naming: `invite_v1.html`, `invite_reminder_v1.html`, etc.
