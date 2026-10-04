# Email templates

Product transactional mail (invites, reminders) — rendered by the worker and sent via **Mailjet**.

- Keep templates in this folder (HTML + plain-text parts).
- Auth lifecycle mail (verification, password reset) stays on **Firebase Auth**, not Mailjet.

Naming: `invite_v1.html`, `invite_v1.txt` (and future templates added to `scripts/sync-email-templates.sh`).

After editing `invite_v1.*` here, run from repo root: `bash scripts/sync-email-templates.sh apply` (CI runs `check` on every PR).
