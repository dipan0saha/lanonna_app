# La Nonna — Play launch checklist (owner)

Docs-only deliverable; no deploy performed from the legal-pages PR. Use with `docs/legal/data-inventory.md`, `docs/legal/privacy-policy.md`, `docs/legal/terms-of-service.md`, and `docs/store/play-listing.md`.

---

## Placeholders to fill before publish

| Placeholder | Used in |
|-------------|---------|
| `{{COMPANY_OR_DEVELOPER_NAME}}` | Legal pages, Play listing footer, store contact |
| `{{CONTACT_EMAIL}}` | Privacy, Terms, Play listing, Data safety “deletion contact” |
| `{{DOMAIN}}` | Policy URLs, invite hosting, Play listing links |
| `{{EFFECTIVE_DATE}}` | Legal effective dates |
| `{{JURISDICTION}}` | Governing law / venue |

---

## Legal and policy

- [ ] Lawyer reviews `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md` (especially baby/child data, retention, liability caps).
- [ ] Replace all placeholders in markdown **and** `hosting/public/legal/*.html`.
- [ ] Deploy Firebase Hosting (`hosting/`) so `https://{{DOMAIN}}/legal/privacy` and `/legal/terms` are live (deploy scripts unchanged in legal PR—run your normal hosting deploy).
- [ ] Update in-app bundled legal HTML (`apps/mobile/assets/legal/`) to match published web copy (separate change from docs PR if desired).
- [ ] Confirm Mailjet sender domain, Firebase Auth email templates, and invite copy list the correct operator name.
- [ ] Document subprocessors (Google Cloud/Firebase, Mailjet) and sign DPAs/SCCs as needed.

---

## Google Play Console

- [ ] Create or access Play Developer account (one-time fee, identity verification).
- [ ] App access: provide test credentials or instructions for reviewers (use dedicated test users; never commit real passwords).
- [ ] Upload **AAB** built with production flavor (`com.lanonna.lanonna`).
- [ ] **App signing:** confirm Play App Signing; secure upload key backup offline.
- [ ] Store listing: paste short/full description from `docs/store/play-listing.md`.
- [ ] Graphics: hi-res icon, feature graphic, ≥2 phone screenshots.
- [ ] **Data safety:** complete form using table in `docs/store/play-listing.md`.
- [ ] **Content rating:** IARC questionnaire using notes in `docs/store/play-listing.md`.
- [ ] **Target audience and Families:** declare adults; review policies for child-related user content.
- [ ] Privacy policy URL: `https://{{DOMAIN}}/legal/privacy`.
- [ ] Contact email in store listing: `{{CONTACT_EMAIL}}`.

---

## Security and operations

- [ ] Production Firebase project: complete **App Check** setup (Play Integrity / App Attest, token TTL, then `APP_CHECK_ENFORCE=true`) per [mobile-prod-flavor-and-crashlytics.md § Owner follow-up step 7](../engineering/mobile-prod-flavor-and-crashlytics.md#prod-app-check); restrict API keys; confirm Crashlytics matches the privacy policy.
- [ ] Confirm account deletion and export flows on a production-like build (including worker `storage_cleanup_completed` logs and GCS objects removed).
- [ ] Disclose **async** media deletion timing in published privacy policy if counsel requires.
- [ ] Incident response contact and breach notification process (`{{CONTACT_EMAIL}}`).

---

## Open questions (from data inventory)

- [ ] Retention period for tombstoned `app_users` rows (profile PII is cleared; row kept for attribution on shared babies; sole-owned babies are **hard-deleted** from Postgres — see `docs/engineering/rca/account-deletion-user-data-audit.md`, `docs/engineering/rca/baby-hard-delete.md`).
- [ ] Privacy copy for failed or delayed `storage_cleanup_jobs` (sweep every 15 minutes; user contact path).
- [ ] Whether `email_digest_enabled` should be disclosed as “email digest” when only weekly **push** digest is implemented in worker.
- [ ] COPPA / GDPR Art. 8 / UK ICO guidance for baby photos and identifiers.
- [ ] Regions of Cloud SQL and GCS (transfer disclosures).
- [ ] Sync Play “Data shared” vs “Data collected” with Firebase Crashlytics and FCM.

---

## Repository artifacts (this effort)

| Path | Purpose |
|------|---------|
| `docs/legal/data-inventory.md` | Code-derived inventory |
| `docs/legal/privacy-policy.md` | Privacy draft (markdown) |
| `docs/legal/terms-of-service.md` | Terms draft (markdown) |
| `hosting/public/legal/` | Static HTML for Firebase Hosting |
| `docs/store/play-listing.md` | Descriptions + Data safety worksheet |
| `docs/store/launch-checklist.md` | This checklist |
