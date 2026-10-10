# Email templates

Product transactional mail (invites, reminders) — rendered by the worker and sent via **Mailjet**.

- Keep templates in this folder (HTML + plain-text parts).
- Auth lifecycle mail (verification, password reset) stays on **Firebase Auth**, not Mailjet — templates live in [`packages/firebase-auth-email-templates`](../firebase-auth-email-templates) and are applied with `scripts/sync-firebase-auth-templates.sh`.

Naming: `invite_v1.html`, `invite_v1.txt` (and future templates added to `scripts/sync-email-templates.sh`).

Invite body copy is role-specific: templates use `{{invite_intro_text}}` / `{{invite_intro_html}}`, filled by `services/worker/src/lanonna_worker/invite_email_copy.py` (follower vs co-owner).

After editing `invite_v1.*` here, run from repo root: `bash scripts/sync-email-templates.sh apply` (CI runs `check` on every PR).
