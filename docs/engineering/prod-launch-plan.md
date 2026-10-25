# La Nonna production launch plan

> **Source of truth:** this document is the source of truth for the La Nonna production launch from **25 Oct 2026** onward. It replaces the Grok Bot Page it was converted from; update it here via PR.
>
> Everything between today's dev setup and La Nonna live on Google Play: 15 phases (0–14) with owner, dependencies, command and check for each item, what only Dipan can decide or click, and cheaper email options. Status as of 25 Oct 2026, repo main at 5ef8a75 (item 11.3 updated for PR #445, main at c12beba).
>
> No addresses, account IDs, keys or secret values belong in this file. Where a value is needed it appears as a placeholder such as `<ID>` or `<addr>`, and the real value goes only into gitignored files, Secret Manager or gcloud.

**Legend.** Owner "Grok Bot (after Dipan's OK)" = Grok Bot runs it by CLI, API or code through executors on Dipan's Mac with his logins, after he approves the phase (D1). "Dipan" = a decision or physical step. "Dipan (console only)" = no API exists. Status values: Open, Done, Partly, Blocked, Unverified, Decision. ⚠️ in email tables = couldn't be confirmed on the official page.

## Contents

- [Where things stand](#where-things-stand)
- [Inputs and decisions needed from Dipan](#inputs-and-decisions-needed-from-dipan)
- [Manual steps only Dipan can do](#manual-steps-only-dipan-can-do)
- [Console settings: API or console only](#console-settings-api-or-console-only)
- [Email provider options](#email-provider-options)
- [Notes and old TODOs, checked](#notes-and-old-todos-checked)
- [Critical path](#critical-path)
- [Phases 0–14 checklist](#phases-014-checklist)
- [Runbook corrections](#runbook-corrections)
- [Couldn't verify](#couldnt-verify)
- [Review log](#review-log)
- [Sources](#sources)

## Where things stand

| Item | Value |
|---|---|
| Prod project | Not created |
| Repo | main at 5ef8a75, 52 migrations (c12beba after PR #445) |
| Region | us-central1 |
| Package id | com.lanonna.lanonna |
| Target SDK | 36 (meets Play's 2026 rule) |
| Items done | 10 |
| Open or partly done | 105 |
| Blocked | 1 |
| Grok Bot items | 99 |
| Dipan items (incl. console only) | 18 + 12 |
| Mac CLIs with Dipan's logins | gcloud, firebase, terraform, flutter, adb: Grok Bot runs them after Dipan's OK |
| Emulator | On the Mac, for Maestro and screenshots |
| Code | PRs from the repo; Dipan OKs the merge |
| Play Console | No access (M4 adds API access) |
| AWS (if SES) | None until Dipan creates the account |

Grok Bot runs every step that can be done by CLI, API or code, including those that change prod, through executors on Dipan's Mac with his logins, after he approves each phase (D1). Those rows say "Grok Bot (after Dipan's OK)". Rows owned by Dipan are decisions or physical steps; "Dipan (console only)" rows have no API. Every one of them is in the two lists below.

## Inputs and decisions needed from Dipan

23 items. Values that are addresses go only into gitignored files or gcloud, never the repo.

| ID | Value or decision | Why it's needed | Needed by |
|---|---|---|---|
| D1 | Go-ahead for each phase before Grok Bot runs its prod-changing commands | Your rule: executors change prod only after you OK the phase | Start of every phase (1–14) |
| D2 | Region: keep `us-central1` | Scripts, state bucket and Cloud SQL connection names assume it (0.1) | Phase 1 |
| D3 | Billing account to link, and budget amounts (dev uses $50 / $150 / $300) | `gcloud billing projects link` and `gcloud billing budgets create` need the account ID and amounts (1.2, 1.3). Your login must be billing admin | Phase 1 |
| D4 | Recipients for alerts and Essential contacts (security, billing, technical) | Written only to gitignored tfvars and gcloud, never to the repo (1.7, 2.5) | Phase 1 |
| D5 | Storage soft delete on prod photo buckets: keep 7 days and disclose, or turn off | Terraform setting in 2.4, and the privacy policy must match (0.10) | Phase 2 |
| D6 | OK to reuse the dev Mailjet sender and API keys for prod in the interim | Grok Bot copies them between gitignored file and secrets without printing (4.4, 6.2) | Phase 4 |
| D7 | Confirm App Check stays off at launch | `prod.api.env` says true today (7.1) | Phase 7 |
| D8 | Hosts compiled into the app: Google hosts (`run.app`, `lanonna-prod.firebaseapp.com`) or a custom domain | Changing later needs an app update (0.4, 11.6) | Phase 11 (first prod AAB) |
| D9 | Package id: keep `com.lanonna.lanonna` | Firebase app, Play listing and assetlinks use it (0.3) | Phase 8 |
| D10 | Play account type: personal or organization (D-U-N-S) | Personal accounts need 12+ testers for 14 days before production (0.2) | Now (sets the timeline); latest Phase 13 |
| D11 | Public contact, support and privacy addresses | Prod `SUPPORT_EMAIL`, store listing, PR #351 (0.6, 10.3, 13.5) | Phase 10 |
| D12 | Domain name to buy, and whether its DNS goes in Cloud DNS | Needed for an own-domain sender (SPF/DKIM/DMARC), contact address and legal pages. In Cloud DNS, Grok Bot does the records (0.11) | Before the email move; not launch-blocking |
| D13 | Long-term email provider (see Email provider options) | Adapter PR, secrets and DNS records depend on it (6.8) | After D12; before 14.6 |
| D14 | Scope of in-app report content / report user | Play UGC policy for invite-only shared photos and comments (0.12) | Before Phase 13 review |
| D15 | PR #351 blanks: developer or company name, effective date, governing law (contact and domain come from D11, D12) | Privacy policy and terms can't publish with placeholders (13.3) | Phase 13 |
| D16 | Store category (Parenting) and 18+ audience; answers for the Health apps declaration | App content forms (0.9, 13.9) | Phase 13 |
| D17 | App icon (512 px) and feature graphic (1024×500): provide or approve. Grok Bot captures the screenshots on the emulator for your approval | Store listing (11.11, 13.5) | Phase 13 |
| D18 | Closed-test tester list (12+ Google accounts) if personal account | Play testing requirement (13.11) | Phase 13 |
| D19 | Review and OK to merge each Grok Bot PR (2.4, 2.7, 3.6, 7.1, 7.3, 9.3, 10.1–10.3, 11.3–11.5, 11.7, 12.3, 13.7, 6.8) | Prod deploys must come from reviewed `main` | Before the phase that uses them |
| D20 | Merge or close QA plan PR #363 | Decides which checklist 12.x uses (12.6) | Phase 12 |
| D21 | Go-ahead to turn App Check enforcement on | Sideloaded builds start getting 401 (12.9) | After 12.4 |
| D22 | Go-ahead for each rollout step 10 % → 50 % → 100 % | Production release (13.12) | Phase 13 |
| D23 | Gmail and Outlook test inboxes for the deliverability check (yours, or Grok Bot's own inbox) | Invite-email spam check (6.7) | Phase 6 |

## Manual steps only Dipan can do

22 steps. Grok Bot prepares everything around them and says when each is due.

| ID | Step | Where | How | When |
|---|---|---|---|---|
| M1 | Play developer account: sign up, pay the $25 fee, pass identity verification (plus D-U-N-S if organization) | play.google.com/console/signup | Sign in with the Google account that will own the app → choose personal or organization (D10) → pay $25 → upload ID and confirm contact phone and email | Start now; verification can take days |
| M2 | Android developer verification: register the package name | Play Console → Developer account → Android developer verification | Add `com.lanonna.lanonna` and complete the steps shown | Phase 13 |
| M3 | Create the app (no API can create a Play app) | Play Console → Home → Create app | Name La Nonna, default language, App, Free, tick the declarations → Create app | Phase 13 |
| M4 | Optional: give Grok Bot Play API access so it can upload AABs, set tracks, testers, rollout and listing text | Play Console → Users and permissions → Invite new users | Enter the deployer service account email Grok Bot gives you → App permissions for La Nonna: Release to testing tracks, Release to production, Manage store presence → Invite. Without this, every upload and rollout step stays yours | Before 13.4 |
| M5 | First AAB upload (Play requires the first one in the console), accept Play App Signing, copy the signing fingerprints | Play Console → Test and release → Testing → Internal testing → Create new release; then Test and release → App integrity → App signing | Upload the AAB Grok Bot built (path on your Mac) → Save → Review → Roll out. On App integrity copy the app-signing SHA-1 and SHA-256 (not secret) into chat | Phase 13 (13.4) |
| M6 | Link the Cloud project for Play Integrity | Play Console → Test and release → App integrity → Play Integrity API | Link a Cloud project → choose `lanonna-prod` → Link | Phase 13, before 8.8 is useful |
| M7 | App content declarations | Play Console → Policy and programs → App content | Privacy policy URL (13.6); App access: paste the reviewer credentials Grok Bot stored for you (13.10); Ads: No; Content rating: IARC questionnaire noting user interaction and shared photos; Target audience: 18+; Data safety: enter Grok Bot's draft (13.8); Data deletion URL (13.7); Health apps and other declarations (D16) | Phase 13 |
| M8 | Store settings (and listing if M4 is skipped) | Play Console → Grow users → Store presence → Store settings / Main store listing | Category Parenting, contact details (D11). Without M4, also paste Grok Bot's listing text and upload icon, feature graphic and screenshots | Phase 13 |
| M9 | Closed test and production access application | Play Console → Test and release → Testing → Closed testing; then Dashboard → Apply for production | Add the D18 testers (email list or Google Group), share the opt-in link, wait 14 days with 12+ opted in, then answer the production access questions | Phase 13 (personal account only) |
| M10 | Read the pre-launch report | Play Console → Test and release → Pre-launch report | Open the latest internal-test report; share crashes or policy flags in chat (no API exposes it) | Phase 12 (12.5) |
| M11 | Enable the Google sign-in provider | Firebase console → lanonna-prod → Authentication → Sign-in method → Add new provider → Google | Enable → public-facing name La Nonna → project support email → Save. This auto-creates the web OAuth client; there's no public API to create that client, and the Identity Toolkit API needs its ID and secret | Phase 8 (8.3b) |
| M12 | OAuth branding shown on the Google sign-in screen | Cloud console → Google Auth Platform → Branding (project lanonna-prod) | App name, user support email, logo, home page, privacy and terms links → Save (the old IAP OAuth Admin API is being shut down) | Phase 8; links after 13.3 |
| M13 | Crashlytics alert emails | Firebase console → Project settings → Alerts (per-user) | Turn on new fatal issue, regressed issue and velocity alerts for La Nonna | Phase 9 (9.6) |
| M14 | Only if shown: Crashlytics Enable button | Firebase console → Crashlytics | If the dashboard still asks to enable after Grok Bot's test crash, click Enable | Phase 8 (8.10) |
| M15 | Buy the domain; registrar DNS if not in Cloud DNS; Search Console verification only if a custom API domain is chosen | Your registrar (or Cloud Domains, which Grok Bot can drive once you approve the purchase) | Buy the D12 name. If DNS stays at the registrar, add the records Grok Bot lists (provider DKIM/SPF/DMARC, Hosting). For a Cloud Run domain mapping, verify the domain in Search Console | Before 6.8 / 7.6 |
| M16 | Offline backup of the upload keystore and its passwords | Your password manager plus offline media | Copy `apps/mobile/android/lanonna-upload.jks` and the passwords from `key.properties`; restore it once to check | Before 13.4 |
| M17 | Legal review of PR #351 | Your lawyer | Review privacy policy and terms after Grok Bot fills the blanks (D15) | Phase 13 (13.3) |
| M18 | Email provider accounts and agreements | Mailjet account settings (DPA now); later the chosen provider (D13) | Accept the Mailjet DPA. For the move: sign up, add payment, accept terms and DPA. For Amazon SES, create the AWS account; Grok Bot then files production access by CLI | Phase 10 (DPA); 6.8 (move) |
| M19 | Real-phone check of the Play install | Your Android phone with the Play internal-test install | Run 12.4. If the phone is plugged into the Mac with USB debugging on, Grok Bot can drive it with adb; Google sign-in and Play Integrity need a real Play install | Phase 12 (12.4) |
| M20 | Paging channel | Google Cloud mobile app, or Monitoring → Notification channels → SMS | Sign in on the app, or enter the SMS verification code | Phase 14 (14.4) |
| M21 | Only if the template sync fails with `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`: Firebase support request | firebase.google.com/support/contact | Submit the text Grok Bot prepares from `scripts/firebase-auth-template-support-request.md` | Phase 8 (8.6) |
| M22 | Sign in again when gcloud, ADC or Firebase CLI tokens expire | Terminal on the Mac (browser opens) | `gcloud auth login`, `gcloud auth application-default login`, `firebase login --reauth`. Grok Bot stops and asks when a command reports expired credentials | Any phase |

## Console settings: API or console only

Each Firebase, GCP and Play setting checked for a CLI or REST API on 25 Oct 2026.

| Setting | Owner | API, CLI or reason |
|---|---|---|
| Create project, link billing | Grok Bot (after Dipan's OK) | `gcloud projects create`, `gcloud billing projects link` |
| Budgets and threshold emails | Grok Bot (after Dipan's OK) | `gcloud billing budgets create` (Cloud Billing Budget API; your login needs billing admin) |
| Essential contacts | Grok Bot (after Dipan's OK) | `gcloud essential-contacts create` |
| Cloud Build SA roles | Grok Bot (after Dipan's OK) | `gcloud projects add-iam-policy-binding` |
| Add Firebase, Android app, SHA fingerprints | Grok Bot (after Dipan's OK) | Terraform `google_firebase_project`; `firebase apps:create`, `firebase apps:android:sha:create` |
| Email/Password provider | Grok Bot (after Dipan's OK) | Identity Toolkit Admin v2 `projects.updateConfig` (`signIn.email`) |
| Google sign-in provider | Dipan (console only) | `defaultSupportedIdpConfigs` exists but needs a web OAuth client ID and secret, and clients can't be created by API → M11 |
| OAuth branding / support email | Dipan (console only) | No supported API (IAP OAuth Admin API deprecated) → M12 |
| Authorized domains | Grok Bot (after Dipan's OK) | `projects.updateConfig` `authorizedDomains` |
| Auth email templates, sender name, action URL | Grok Bot (after Dipan's OK) | `projects.updateConfig` `notification.sendEmail` (repo scripts already use it); support ticket if blocked → M21 |
| App Check: Play Integrity provider and token TTL | Grok Bot (after Dipan's OK) | Firebase App Check REST `projects.apps.playIntegrityConfig.patch` with `tokenTtl` (30 min–7 days) |
| Link Cloud project to Play Integrity | Dipan (console only) | Play Console only → M6 |
| Crashlytics enable | Grok Bot (after Dipan's OK) | API enabled by Terraform; first report from the SDK activates it. No enable API found; M14 if the console still asks (unverified) |
| Crashlytics alerts | Dipan (console only) | Per-user console setting, no API found → M13 |
| Android API key restriction | Grok Bot (after Dipan's OK) | `gcloud services api-keys update --allowed-application=sha1_fingerprint=…,package_name=…` |
| Error notifications for api and worker | Grok Bot (after Dipan's OK) | Terraform log-based alert policy (replaces the console-only Error Reporting toggle) |
| Alert fire drill | Grok Bot (after Dipan's OK) | Temporary always-firing policy via Terraform or `gcloud monitoring policies create`, then delete |
| Play: upload, tracks, testers, rollout %, listing text, contact details | Grok Bot (after Dipan's OK) | Google Play Developer API (`edits.bundles.upload`, `edits.tracks.update` with `userFraction`, `edits.listings`, `edits.details`, `edits.testers`) once M4 is done; first upload stays console (M5) |
| Play: create app, App content forms, category, pre-launch report, production access | Dipan (console only) | No API → M3, M7, M8, M9, M10 |

## Email provider options

Official pricing pages read 25 Oct 2026, monthly USD before tax. ⚠️ = couldn't be confirmed on the official page.

> **Constraint from Google Cloud.** Google Cloud has no transactional email service of its own and blocks outbound port 25, so the provider must take an HTTPS API call (what the worker does today) or SMTP on 587 or 2525. Every option below does.

> **La Nonna's volume.** At 5ef8a75 the worker sends one kind of email: invitations (`invite_email.py`, the only caller of `mailjet_send.send_messages`). The weekly digest and notifications are push and in-app, not email. Firebase Auth sends verification and password-reset mail itself, so those don't count. At 5–10 invites per new family: 100 new families a month is 500–1,000 emails, 500 is 2,500–5,000, and 10,000 needs about 1,000–2,000 new families a month. Expect under 3,000 a month in year one.

### Cost

| Provider | Free tier | Cheapest paid plan | ~3k / mo | ~10k / mo | ~50k / mo |
|---|---|---|---|---|---|
| Amazon SES | None ongoing; new AWS accounts get up to $200 credits | Pay as you go $0.10 / 1,000 (à la carte). New accounts default to Essentials $0.16 / 1,000; switch any time | $0.30 | $1.00 | $5.00 |
| Brevo | 300 / day (~9,000 / mo) | Starter $9 for 5,000 | $0 | $17 | $56 |
| Resend | 3,000 / mo, 100 / day | Pro $20 for 50,000 | $0 | $20 | $20 |
| Mailgun | 100 / day (~3,000 / mo) | Basic $15 for 10,000 | $0 | $15 | $35 (Foundation) |
| MailerSend | 500 / mo, card required | Hobby $7 for 5,000 | $7 | $14.50 | $35 (Starter) |
| SMTP2GO | 1,000 / mo, 200 / day | Starter $10 for 10,000 on the plan card; page title says from $15 ⚠️ | $10–15 ⚠️ | $10–15 ⚠️ | ~$58–63 (Starter + $1.20/1k), or $75 Professional ⚠️ |
| SendGrid | 60-day trial only, 100 / day, then sending stops | Essentials $19.95 for 50,000 | $19.95 | $19.95 | $19.95 |
| Postmark | 100 / mo | Basic $15 for 10,000 | $15 | $15 | ~$68.50 (Pro + overage); tier prices not read ⚠️ |
| Mailjet (today) | 6,000 / mo, 200 / day, Mailjet logo | Starter $9 for 8,000 | $0 | $19 (Essential 15k) | $40 (Essential 50k) |

### Fit with Cloud Run

| Provider | From Cloud Run | Domain records | Deliverability | Catches |
|---|---|---|---|---|
| Amazon SES | HTTPS API (SESv2 `SendEmail`) or SMTP 587 / 2525; not on GCP Marketplace. Credentials: IAM key in Secret Manager, or keyless via AWS web-identity federation from the Cloud Run service account | Easy DKIM (3 CNAMEs), custom MAIL FROM for SPF alignment, DMARC | Strong once out of sandbox; you must handle bounces and complaints (SNS) or risk suspension | Starts in sandbox (verified recipients only, low daily cap) until production access is approved; needs an AWS account; dedicated IP $24.95/mo optional |
| Brevo | HTTPS API or SMTP relay 587 | Brevo code + DKIM, DMARC required for domain authentication | Shared IPs; marketing-heavy suite | Account approval before sending; Brevo logo on Starter unless the $12/mo remover; dedicated IP only on top plans |
| Resend | HTTPS API (simplest), SMTP 587 / 2525 | SPF + DKIM records required, DMARC recommended | Shared IPs; dedicated IP only on Scale | Free cap 100/day can stall an invite burst; 30-day log retention on free |
| Mailgun | HTTPS API or SMTP 587 / 2525; on GCP Marketplace (Google's own tutorial) | SPF, DKIM, DMARC | Mature; same owner (Sinch) as Mailjet | 1-day logs on free and Basic; Basic is 1 domain; dedicated IP $59 |
| MailerSend | HTTPS API or SMTP 587 / 2525 | SPF, DKIM, return-path CNAME, DMARC | Shared IPs | Account approval; card even for free; MailerSend logo until Starter; Hobby keeps 1 day of activity |
| SMTP2GO | HTTPS API or SMTP 587 / 2525 / 8025 | SPF and DKIM via CNAMEs, DMARC | Shared IPs; dedicated IP on Professional | Free can't exceed its cap; Starter price inconsistent on the page |
| SendGrid | HTTPS API or SMTP 587 / 2525; on GCP Marketplace (Twilio docs) | Domain authentication CNAMEs (SPF, DKIM), DMARC | Large shared pools; dedicated IPs from Pro | No free plan since 2025; Essentials has 1 teammate |
| Postmark | HTTPS API or SMTP 587 / 2525 | DKIM + Return-Path CNAME, DMARC | Best known for transactional inbox rates | Nothing between 100 and 10,000 a month; account review; transactional only in that stream |
| Mailjet (today) | HTTPS API v3.1 (current code) or SMTP 587 / 2525 | SPF, DKIM, DMARC | Today's Gmail-address sender fails DMARC alignment (6.7) | Prices rose 9 Sep 2026; logo on free |

> **Recommendation: Amazon SES.** Cheapest at every volume (about $0.30 a month at 3k, $5 at 50k, on à la carte pricing) with strong deliverability once the domain has DKIM, custom MAIL FROM and DMARC. Costs: an AWS account (M18), a production-access request, bounce and complaint handling, and the adapter PR (6.8). If running an AWS account isn't wanted, take Resend: free to 3,000 a month (100 a day) and a flat $20 up to 50,000, with the simplest HTTPS API. Either way the real prerequisite is an own domain (D12); staying on Mailjet free (6,000 a month, max 200 a day) costs nothing until then.

### Staying on Mailjet without a domain

Mailjet can keep working without a domain: it sends from the single verified sender address, as dev does today. The downsides for prod:

- **Deliverability.** A free-mailbox From address (e.g. Gmail) sent through Mailjet can't pass DMARC alignment, so more invites land in spam and some providers may reject them (see 6.7).
- **Branding.** The free plan adds Mailjet's footer, and a free-mailbox sender looks less trustworthy than an own-domain address.
- **Other uses.** Without a domain the public privacy/support contact would be a personal mailbox, and invite links and legal pages stay on Firebase hosts (`lanonna-prod.web.app` / `.firebaseapp.com`).

So launch on Mailjet without a domain is possible; a domain (about $11 a year) fixes all three, whichever provider is chosen.

### Domain registrar comparison

Prices checked 25 Oct 2026, USD per year for one domain. **Recommendation: Porkbun** (no catch found; free privacy; any DNS provider, including Cloud DNS).

| Registrar | .com 1st yr | .com renewal | .app 1st yr | .app renewal | Catch |
|---|---|---|---|---|---|
| Porkbun (recommended) | $11.08 | $11.08 | $8.75 | $14.93 | None found |
| Cloudflare | $10.46 | $10.46 | $8.20 | $14.20 | Must use Cloudflare's DNS. Prices from a third-party price tracker (Cloudflare shows them only after sign-in) |
| Namecheap | $11.28 | $18.48 | $10.98 | $22.98 | Renewals jump a lot |
| Squarespace | about $10 | not confirmed | about $30 | not confirmed | .app went up to ~$30 this month per a price tracker; unconfirmed |
| GoDaddy | $0.01 with a 3-year purchase | $22.99 | $15.99 | $27.99 | Pricey renewals; checkout pushes paid add-ons |

All five include free WHOIS privacy and allow the DNS records an email provider needs (DKIM, SPF, DMARC). Namecheap and GoDaddy add a $0.20 yearly ICANN fee at checkout; the others include it. Pricing pages: [Porkbun](https://porkbun.com/products/domains), [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/), [Namecheap](https://www.namecheap.com/domains/), [GoDaddy](https://www.godaddy.com/pricing).

## Notes and old TODOs, checked

Checked against main 5ef8a75 and, read-only, lanonna-dev on 25 Oct 2026 (build-number row updated for PR #445).

| Note | From | Status | Evidence |
|---|---|---|---|
| Crashlytics enabled in lanonna-dev | Dipan msg 1, item 3 | Done | API enabled; stamped events in dev. Prod in 8.10 |
| In-app Terms and Privacy: samples, not reachable from Settings | Dipan msg 1, item 5 | Still open | Assets titled '(Sample)'; only linked from onboarding (10.1) |
| `deploy-invite-hosting.sh` failed at the IAM step | Dipan msg 1, item 6 | Done | IAM step removed in #349; not yet run against prod |
| Personal emails in the public repo | Dipan msg 1, item 6 | Partly done | 0 in tracked files at 5ef8a75; still in git history by your choice |
| PR #351 legal pages and store listing | Dipan msg 1, item 4 | Still open | Open draft; 5 placeholders; no deletion-request page |
| PR #363 pre-prod QA plan | Brief | Still open | Open, unmerged |
| Migrations 048/049 after the API deploy | pre-prod-consolidation.md | Done | Safe on an empty DB; rule only matters for a running prod |
| Run `setup-schedulers.sh` | pre-prod-consolidation.md | Done | Dev has 4 ENABLED; prod is 6.6 |
| Worker deploy before API | pre-prod-consolidation.md | Done | 6.4 → 6.5 → 7.2 |
| Dev monitoring on so the email alert works | pre-prod-consolidation.md | Still open | Dev has only the DLQ policy, 0 channels (9.2) |
| Launch checklist in mobile-prod-flavor doc | mobile-prod-flavor-and-crashlytics.md | Partly done | Keystore exists; rest mapped into phases 8, 11, 13 |
| Same sender and Mailjet account as dev; move to a cheaper provider long term | Dipan msgs 1 and follow-up | Still open | Interim via gitignored `prod.worker.local.env` (6.2); move in 6.8 per Email provider options |
| App Check off in prod until Play is linked | Dipan msg 1, item 2 | Still open | `prod.api.env` still says true (7.1) |
| Google sign-in needs the upload key; debug key not reused | Dipan msg 1, item 2 | Partly done | Upload keystore exists; SHA registration in 8.2 |
| Prod DB deletion protection on | Dipan msg 1, item 2 | Done | `sql_deletion_protection = true` in prod Terraform |
| Register prod signing SHA-256; longer App Check TTL | Dipan msg 1, item 5 | Still open | TTL settable by REST (8.8); Play link is console only (M6) |
| App Check debug-token script prints the token | Dipan msg 1, item 6 | Still open | Still echoes it; dev-only, can't reach prod |
| `delete_dev_account.sh` breaks on Python 3.14 | Dipan msg 1, item 6 | Couldn't verify | Not reproduced; dev-only |
| Build numbers go backwards after squash merges | Dipan msg 1, item 6 | Done | Fixed in #444 / PR #445 (merged c12beba); see 11.3 |
| Upload key and Play Console | Dipan msg 1, item 3 | Partly done | Keystore on the Mac; backup (M16) and enrollment (M1) pending |
| Has lanonna-prod been created? | Read-only check | Still open | Not visible to the Mac's gcloud account; state bucket 404 |

## Critical path

1. **You: decisions D2–D11, start M1 (Play account) and M16 (keystore backup)** — Grok Bot opens the pre-apply PRs: 2.4, 7.1, 7.3; local gate green; you OK merges (D19)
2. **Grok Bot: project, billing, budgets, state bucket** — 1.1–1.7, 2.2 after your OK for phase 1–2
3. **Grok Bot: Terraform phase 1** — 2.6: SQL, buckets, topics, SAs, secret containers, monitoring
4. **Grok Bot: secrets and migrations** — Phase 4, then 3.4–3.5
5. **Grok Bot: worker, invoker IAM, phase-2 apply, schedulers** — 6.4, 6.5, 6.6
6. **Grok Bot: API, uptime check** — 7.2, 7.4
7. **Firebase: Grok Bot does app, SHA, Auth config, Hosting; you enable Google sign-in and branding** — 8.1–8.10; M11, M12
8. **Prod AAB: Grok Bot builds, you do the first upload** — 13.4a–c; M3, M5, M6
9. **Verify on your phone** — 12.4 (M19); Grok Bot runs the restore and alert drills
10. **Closed test, listing, App content** — M7–M9; Grok Bot drafts every answer
11. **Staged rollout, then App Check enforcement** — 13.12 (D22), 12.9 (D21)

## Phases 0–14 checklist

Each item: owner, needs (D = input, M = manual step, or item IDs), status, then the command or console location and how to verify. Ticked = Done as recorded.

### Phase 0: Decisions and inputs

_Every row here is also in Inputs and decisions (D-codes). 0.1–0.4 must be settled before the first prod AAB, because hosts and the package id are compiled into the app._

- [ ] **0.1** Region: keep `us-central1` (every script, the state bucket and Cloud SQL connection names assume it)
  - Owner: Dipan · Needs: D2 · Status: Decision
  - How: Confirm only. Defaults in `scripts/lib/env.sh`, `services/*/scripts/deploy.sh`, `ensure-state-bucket.sh`
  - Verify: `terraform.tfvars` has `region = "us-central1"`
- [ ] **0.2** Play developer account: personal or organization. Personal accounts created after 13 Nov 2023 must run a closed test with 12+ opted-in testers for 14 days before production; organization accounts (need a D-U-N-S number) are exempt
  - Owner: Dipan · Needs: D10 · Status: Decision
  - How: Chosen during M1
  - Verify: Account type noted here; tester list ready if personal
- [ ] **0.3** Package id: keep `com.lanonna.lanonna` (already in `build.gradle.kts`, migration 020's Play URL and assetlinks). Dev uses the same id, so dev and prod can't be installed side by side
  - Owner: Dipan · Needs: D9 · Status: Decision
  - How: No change if kept
  - Verify: `build.gradle.kts` applicationId
- [ ] **0.4** Hosts compiled into the app: API (`run.app` vs custom domain) and App Link host (`lanonna-prod.firebaseapp.com` vs custom). Recommend Google hosts for v1
  - Owner: Dipan · Needs: D8 · Status: Decision
  - How: `apps/mobile/flavors/prod.json` `API_BASE_URL`, `APP_LINK_HOST`; worker hardcodes `https://<project>.firebaseapp.com` for invite links
  - Verify: Values filled in 11.6
- [ ] **0.5** Interim prod sender: same Mailjet account and sender as dev; long term move to a cheaper provider on your own domain (6.8)
  - Owner: Dipan · Needs: D6, D13 · Status: Decision
  - How: Sender goes in gitignored `infra/env/prod.worker.local.env`, never the tracked `prod.worker.env`
  - Verify: `git status` clean; worker deploy accepts the sender
- [ ] **0.6** Public contact address for the store listing, privacy policy and in-app support. Recommend role addresses on your own domain
  - Owner: Dipan · Needs: D11 · Status: Decision
  - How: Used in PR #351, Play listing, prod `SUPPORT_EMAIL`
  - Verify: Same address in all three
- [ ] **0.7** Budget amounts and alert recipients
  - Owner: Dipan · Needs: D3, D4 · Status: Decision
  - How: Used in 1.3, 1.7, 2.5
  - Verify: Budgets and tfvars set
- [ ] **0.8** App Check off at launch until Play is linked; conflicts with `prod.api.env` `APP_CHECK_ENFORCE=true`
  - Owner: Dipan · Needs: D7 · Status: Decision
  - How: Resolved by 7.1, flipped in 12.9
  - Verify: First prod API revision shows false
- [ ] **0.9** Store category Parenting, 18+ audience (Social would trigger Child Safety Standards)
  - Owner: Dipan · Needs: D16 · Status: Decision
  - How: Entered in M7, M8
  - Verify: Matches 13.9
- [ ] **0.10** Storage soft delete: dev keeps deleted objects 7 days (`softDeletePolicy` 604800 s). Keep and disclose, or turn off on prod photo buckets
  - Owner: Dipan · Needs: D5 · Status: Decision
  - How: Terraform `soft_delete_policy` (2.4)
  - Verify: `gcloud storage buckets describe gs://lanonna-prod-display --format='value(soft_delete_policy)'`
- [ ] **0.11** Own domain (sender, contact, legal pages, optional custom hosts). Doesn't block project creation or the first internal test
  - Owner: Dipan · Needs: D12, M15 · Status: Open
  - How: Buy it; DNS in Cloud DNS lets Grok Bot manage records
  - Verify: Domain resolves
- [ ] **0.12** UGC moderation: no in-app report content / report user action exists. Play's UGC policy asks invite-only UGC apps for in-app reporting
  - Owner: Dipan · Needs: D14 · Status: Decision
  - How: Product decision; implementation is a Grok Bot PR
  - Verify: Feature merged or decision recorded

### Phase 1: Project, billing, budgets, APIs

- [ ] **1.1** Create the GCP project `lanonna-prod`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1 · Status: Open
  - How: `gcloud projects create lanonna-prod --name="La Nonna"`. As of 25 Oct it isn't visible to the Mac's gcloud account and the state bucket returns 404. If the quota is hit, Google shows a request form (yours)
  - Verify: `gcloud projects describe lanonna-prod --format='value(lifecycleState)'` = ACTIVE
- [ ] **1.2** Link the billing account
  - Owner: Grok Bot (after Dipan's OK) · Needs: D3, 1.1 · Status: Open
  - How: `gcloud billing projects link lanonna-prod --billing-account=<ID>`
  - Verify: `gcloud billing projects describe lanonna-prod --format='value(billingEnabled)'` = True
- [ ] **1.3** Budgets with email alerts at 50 / 90 / 100 % plus forecast
  - Owner: Grok Bot (after Dipan's OK) · Needs: D3, 1.2 · Status: Open
  - How: `gcloud billing budgets create --billing-account=<ID> --display-name=lanonna-prod --budget-amount=<amount> --filter-projects=projects/lanonna-prod --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0 --threshold-rule=percent=1.0,basis=forecasted-spend`
  - Verify: `gcloud billing budgets list --billing-account=<ID>` shows it
- [x] **1.4** Org policies: not applicable (no organization parent; per-resource hardening in 2.4)
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Done
  - How: Checked: `gcloud projects describe lanonna-dev` has no parent
  - Verify: No action
- [ ] **1.5** APIs: add the Firebase ones the prod list lacks (`identitytoolkit`, `securetoken`, `fcm`, `firebaseinstallations`, `firebasecrashlytics`) plus `billingbudgets`, `androidpublisher`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19 · Status: Open
  - How: PR editing `standard_apis` (part of 2.4)
  - Verify: `gcloud services list --enabled --project=lanonna-prod` includes them
- [ ] **1.6** Add Firebase to the project (`google_firebase_project`); Blaze follows the linked billing
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Created by the phase-1 apply
  - Verify: `firebase projects:list` shows lanonna-prod
- [ ] **1.7** Essential contacts for security, billing and technical notices
  - Owner: Grok Bot (after Dipan's OK) · Needs: D4, 1.1 · Status: Open
  - How: `gcloud essential-contacts create --email=<addr> --notification-categories=security,billing,technical --project=lanonna-prod`
  - Verify: `gcloud essential-contacts list --project=lanonna-prod`

### Phase 2: IAM, deployer identity, Terraform

- [ ] **2.1** Deployer identity: your Google login on the Mac, used by Grok Bot's executors; no service-account keys; `create_automation_sa = false`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, M22 · Status: Partly
  - How: Existing `gcloud auth login` and ADC
  - Verify: `gcloud iam service-accounts keys list` shows only system-managed keys
- [ ] **2.2** Terraform state bucket, locked down (holds the SQL app password)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 1.2 · Status: Open
  - How: `./infra/terraform/scripts/ensure-state-bucket.sh lanonna-prod lanonna-prod-terraform-state`; `gcloud storage buckets update gs://lanonna-prod-terraform-state --public-access-prevention`
  - Verify: Versioning on, uniform access, PAP enforced, owners only
- [ ] **2.3** ADC quota project for plan/apply; reset to dev afterwards
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.2 · Status: Open
  - How: `gcloud auth application-default set-quota-project lanonna-prod` only if a 403 mentions it
  - Verify: `terraform plan` runs without 403
- [ ] **2.4** Pre-apply hardening PR: (a) prod variable for the worker push subscription; (b) PAP enforced on both buckets; (c) prod CORS `[]`; (d) SQL maintenance window, `ENCRYPTED_ONLY`, query insights; (e) Artifact Registry cleanup policy; (f) APIs from 1.5; (g) soft delete per D5; (h) log-based error alert (9.4)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D5, D19 · Status: Open
  - How: Branch + PR; checks with `scripts/premerge_check.sh`
  - Verify: `terraform validate`; dev plan shows no unintended change
- [ ] **2.5** Prod tfvars from the example; recipients only in the gitignored file
  - Owner: Grok Bot (after Dipan's OK) · Needs: D4 · Status: Open
  - How: `cp terraform.tfvars.example terraform.tfvars`; set `monitoring_notification_emails` without printing; `monitoring_api_host` empty for now
  - Verify: `git status` shows no tracked change
- [ ] **2.6** Phase-1 apply (no push subscriptions yet)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, 2.2–2.5 · Status: Open
  - How: `terraform init && terraform plan -out tfplan`; you see the plan summary before `terraform apply tfplan`
  - Verify: Outputs list SQL connection, buckets, api and worker SAs, secret containers
- [ ] **2.7** Scope `secretmanager.secretAccessor` per secret instead of project-wide
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19, 2.6 · Status: Open
  - How: PR in `modules/platform/iam.tf`
  - Verify: No project-wide secretAccessor
- [ ] **2.8** Cloud Build identity: grant the roles in `operations.md` if the first build fails on permissions
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Unverified
  - How: `gcloud projects add-iam-policy-binding lanonna-prod --member=serviceAccount:<build SA> --role=<role>` for each
  - Verify: First API build succeeds (7.2)

### Phase 3: Cloud SQL and migrations

- [ ] **3.1** Instance from Terraform: PG16 Enterprise, `db-custom-1-3840`, zonal, 10 GB SSD autoresize to 20 GB, backups 03:00 UTC, 7-day PITR, deletion protection on
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: `modules/platform/sql.tf`
  - Verify: `gcloud sql instances describe lanonna-db --project=lanonna-prod --format='value(settings.tier,settings.backupConfiguration.pointInTimeRecoveryEnabled,settings.deletionProtectionEnabled)'`
- [x] **3.2** Public IP with zero authorized networks; Cloud Run connector and Auth Proxy only
  - Owner: Grok Bot (after Dipan's OK) · Needs: 3.1 · Status: Done
  - How: Same as dev
  - Verify: `authorizedNetworks` empty
- [ ] **3.2b** Maintenance window and SSL mode (from 2.4d)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.4 · Status: Open
  - How: Terraform
  - Verify: `maintenanceWindow` and `sslMode: ENCRYPTED_ONLY`
- [ ] **3.3** App DB user `lanonna_app` and `db-lanonna-app-password`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Terraform (`manage_sql_app_password = true`)
  - Verify: 1 enabled version (value never printed)
- [ ] **3.4** `postgres` password: generate, set and store without printing
  - Owner: Grok Bot (after Dipan's OK) · Needs: 3.1 · Status: Open
  - How: Generate with `openssl rand`, pipe into `gcloud secrets versions add db-postgres-root-password --data-file=-` and set with `gcloud sql users set-password postgres` from the same variable
  - Verify: Secret has 1 version; proxy login works
- [ ] **3.5** Apply migrations 001–052 on the empty DB (048/049 are safe before the API on a fresh DB)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, 3.3 · Status: Open
  - How: `cloud-sql-proxy lanonna-prod:us-central1:lanonna-db --port 5434`; `DB_PORT=5434 infra/db/.venv/bin/python infra/db/apply_migrations.py` with the password from Secret Manager
  - Verify: `GCP_PROJECT_ID=lanonna-prod ./scripts/verify-migrations.sh` = 52 of 52
- [ ] **3.6** Dev-only data scripts refuse prod
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19 · Status: Open
  - How: PR adding a refusal when `GCP_PROJECT_ID=lanonna-prod`
  - Verify: Scripts exit non-zero against prod

### Phase 4: Secrets

_Containers come from Terraform. Values are piped, never printed. Don't recreate `database-url`._

- [ ] **4.1** `db-lanonna-app-password`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Terraform
  - Verify: 1 enabled version
- [ ] **4.2** `db-postgres-root-password`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 3.4 · Status: Open
  - How: Added in 3.4
  - Verify: 1 enabled version
- [ ] **4.3** `admin-api-key` (API deploy fails without it)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: `openssl rand -hex 32 | gcloud secrets versions add admin-api-key --data-file=- --project=lanonna-prod`
  - Verify: 1 enabled version
- [ ] **4.4** `mailjet-api-key` and `mailjet-api-secret`, same account as dev
  - Owner: Grok Bot (after Dipan's OK) · Needs: D6, 2.6 · Status: Open
  - How: `gcloud secrets versions access latest --secret=mailjet-api-key --project=lanonna-dev | gcloud secrets versions add mailjet-api-key --data-file=- --project=lanonna-prod` (and the secret)
  - Verify: Each has 1 enabled version
- [ ] **4.5** Inventory: exactly five secrets, no `database-url`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 4.1–4.4 · Status: Open
  - How: `gcloud secrets list --project=lanonna-prod --format='value(name)'`
  - Verify: Five names

### Phase 5: Cloud Storage

- [ ] **5.1** `lanonna-prod-display` and `lanonna-prod-thumbnails`: uniform access, abort-multipart after 1 day
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Terraform
  - Verify: describe shows uniform access and lifecycle
- [ ] **5.2** Public access prevention enforced
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.4b · Status: Open
  - How: Terraform
  - Verify: `public_access_prevention` = enforced
- [ ] **5.3** No CORS for prod
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.4c · Status: Open
  - How: Terraform
  - Verify: `cors_config` empty
- [ ] **5.4** Upload notification → `photo-upload-finalized`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Terraform
  - Verify: `gcloud storage buckets notifications list gs://lanonna-prod-display`
- [ ] **5.5** Soft delete per D5
  - Owner: Grok Bot (after Dipan's OK) · Needs: D5 · Status: Open
  - How: Terraform
  - Verify: describe shows the chosen retention

### Phase 6: Pub/Sub, worker, email

- [ ] **6.1** Topics `photo-upload-finalized`, `lanonna-async-commands`, `-dlq` and the DLQ pull subscription
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Terraform phase 1
  - Verify: 3 topics; `lanonna-async-commands-dlq-pull` listed
- [ ] **6.2** Prod sender in gitignored `infra/env/prod.worker.local.env`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D6 · Status: Open
  - How: Copy `MAILJET_FROM_EMAIL` from the dev local env file without printing
  - Verify: Worker deploy passes its sender check
- [ ] **6.3** Email templates in sync
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Open
  - How: `bash scripts/sync-email-templates.sh check`
  - Verify: Exits 0
- [ ] **6.4** Deploy the worker, then Run invoker IAM
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, 4.1, 4.4, 6.2, 3.5 · Status: Open
  - How: `GCP_PROJECT_ID=lanonna-prod ./services/worker/scripts/deploy.sh`; `GCP_PROJECT_ID=lanonna-prod ./scripts/apply-run-iam.sh`
  - Verify: Revision ready; no allUsers on worker; `/health/live` passing
- [ ] **6.5** Phase-2 apply: push subscriptions with OIDC, DLQ policy and alert
  - Owner: Grok Bot (after Dipan's OK) · Needs: 6.4, 2.4a · Status: Open
  - How: Set the variable from 2.4a, `terraform apply`
  - Verify: 2 push subs to the worker plus DLQ pull sub; DLQ alert exists
- [ ] **6.6** Cloud Scheduler jobs (script, not Terraform)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 6.1 · Status: Open
  - How: `GCP_PROJECT_ID=lanonna-prod ./scripts/setup-schedulers.sh`
  - Verify: 4 ENABLED jobs
- [ ] **6.7** Deliverability check: a Gmail From through Mailjet fails DMARC alignment, so invites may land in spam until 6.8
  - Owner: Grok Bot (after Dipan's OK) · Needs: D23, 6.4 · Status: Open
  - How: Send a real invite to the D23 inboxes
  - Verify: Both arrive in inbox; links open the prod invite page
- [ ] **6.8** Move off Mailjet: provider adapter PR replacing `mailjet_send.py` (only caller is `invite_email.py`), renamed config and secrets, deploy-script sender check, Terraform secret ids and the send-failure log metric
  - Owner: Grok Bot (after Dipan's OK) · Needs: D12, D13, M15, M18, D19 · Status: Open
  - How: PR in `services/worker`, `infra/terraform/modules/platform`, `infra/env`; then new secrets piped in
  - Verify: Invite arrives from the own-domain sender with SPF, DKIM and DMARC pass in the headers
- [ ] **6.9** Provider DNS records (DKIM, SPF or custom MAIL FROM, DMARC `p=none` then tighten)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D12; M15 if DNS isn't in Cloud DNS · Status: Open
  - How: `gcloud dns record-sets create` in the Cloud DNS zone
  - Verify: Provider dashboard shows the domain verified

### Phase 7: Cloud Run API and Artifact Registry

- [ ] **7.1** `APP_CHECK_ENFORCE=false` in `infra/env/prod.api.env` with a dated comment
  - Owner: Grok Bot (after Dipan's OK) · Needs: D7, D19 · Status: Open
  - How: Small PR
  - Verify: File on main says false
- [ ] **7.2** Deploy the API: min 1, max 10, 1 vCPU, 512 Mi, public invoker, Cloud SQL attached
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, 3.5, 4.3, 6.5, 7.1 · Status: Open
  - How: `GCP_PROJECT_ID=lanonna-prod ./services/api/scripts/deploy.sh`
  - Verify: `/health` returns 200; env names match dev
- [ ] **7.3** API fails loudly on dev defaults when `ENVIRONMENT=prod` (worker already does)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19 · Status: Open
  - How: PR in `services/api/src/lanonna_api/config.py` + tests
  - Verify: API refuses to start with any dev default
- [ ] **7.4** Uptime check: set `monitoring_api_host`, apply
  - Owner: Grok Bot (after Dipan's OK) · Needs: 7.2 · Status: Open
  - How: Edit gitignored tfvars, `terraform apply`
  - Verify: `gcloud monitoring uptime list-configs` shows `/health`
- [ ] **7.5** Artifact Registry repo with cleanup policy
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.4 · Status: Open
  - How: Terraform
  - Verify: describe shows the policy
- [ ] **7.6** Custom API domain (only if chosen)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D8, D12, M15 · Status: Decision
  - How: `gcloud beta run domain-mappings create`; domain must be verified in Search Console (M15)
  - Verify: TLS cert active

### Phase 8: Firebase

- [ ] **8.1** Register the Android app in prod Firebase
  - Owner: Grok Bot (after Dipan's OK) · Needs: D9, 1.6 · Status: Open
  - How: `firebase apps:create ANDROID "La Nonna Android" --package-name=com.lanonna.lanonna --project lanonna-prod`
  - Verify: `firebase apps:list --project lanonna-prod`
- [ ] **8.2** Upload-key SHA-1 and SHA-256 (Play signing ones follow in 13.4; debug key deliberately not registered)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.1 · Status: Open
  - How: `./gradlew signingReport` reads `key.properties` itself (no password typed or printed), then `firebase apps:android:sha:create <prodAppId> <sha>`
  - Verify: `firebase apps:android:sha:list <prodAppId>`
- [ ] **8.3a** Email/Password provider on
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.1 · Status: Open
  - How: Identity Toolkit Admin v2 `PATCH projects/lanonna-prod/config?updateMask=signIn.email`
  - Verify: `GET …/config` shows email enabled
- [ ] **8.3b** Google sign-in provider on, public name La Nonna, support address
  - Owner: Dipan (console only) · Needs: M11, M12, D11 · Status: Open
  - How: Firebase console → Authentication → Sign-in method → Google
  - Verify: Both providers enabled
- [ ] **8.4** Prod client config: `firebase_options_prod.dart` and prod `google-services.json`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.2, 8.3b · Status: Open
  - How: `flutterfire configure --project=lanonna-prod`
  - Verify: Prod json has the prod project number and an `oauth_client` of type 3
- [ ] **8.5** Authorized domains (`lanonna-prod.firebaseapp.com`, `.web.app`; custom later)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.3a · Status: Open
  - How: `projects.updateConfig` `authorizedDomains`
  - Verify: Listed in `GET …/config`
- [ ] **8.6** Auth email branding, templates, action URL `/email-verified`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.3a, 8.7 · Status: Open
  - How: `GCP_PROJECT_ID=lanonna-prod bash scripts/configure-firebase-auth-email-project.sh apply` and `… sync-firebase-auth-templates.sh apply`; reset ADC quota project to dev afterwards. M21 if `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`
  - Verify: `check` and `check-remote` pass
- [ ] **8.7** Hosting: invite landing, `/email-verified`, assetlinks, invite-preview rewrite
  - Owner: Grok Bot (after Dipan's OK) · Needs: 7.2, 8.2 · Status: Open
  - How: `GCP_PROJECT_ID=lanonna-prod ANDROID_SHA256=<upload>,<play signing> bash scripts/deploy-invite-hosting.sh` (rerun after 13.4)
  - Verify: assetlinks lists both fingerprints; `/invite?token=x` loads
- [ ] **8.8** App Check: Play Integrity provider, SHA-256s, token TTL 12–24 h; enforcement waits for 12.9; never a debug token in prod
  - Owner: Grok Bot (after Dipan's OK) · Needs: M6, 13.4 · Status: Open
  - How: `PATCH firebaseappcheck.googleapis.com/v1/projects/<number>/apps/<appId>/playIntegrityConfig?updateMask=tokenTtl` body `{"tokenTtl":"43200s"}`
  - Verify: App Check metrics show verified requests from the internal-test build
- [ ] **8.9** FCM: worker role from Terraform; Android 13+ runtime prompt
  - Owner: Grok Bot (after Dipan's OK) · Needs: 6.4 · Status: Open
  - How: Nothing extra
  - Verify: Push received in 12.4
- [ ] **8.10** Crashlytics on in prod
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.1; M14 only if asked · Status: Open
  - How: API on via Terraform; forced test crash from a prod build
  - Verify: Stamped test event appears
- [x] **8.11** Google Analytics off for prod (`firebase_analytics` not a dependency)
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Done
  - How: Checked `pubspec.yaml`
  - Verify: No `AD_ID` in the AAB manifest
- [ ] **8.12** Restrict the prod Android API key to package + SHA-1s
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.2, 13.4 · Status: Open
  - How: `gcloud services api-keys update <key> --allowed-application=sha1_fingerprint=<sha1>,package_name=com.lanonna.lanonna`
  - Verify: Key shows Android restriction with both SHA-1s

### Phase 9: Monitoring, alerting, logs, cost

- [ ] **9.1** Platform alerts from Terraform: API 5xx, p95 latency, uptime, SQL CPU and disk, email send failures, DLQ depth
  - Owner: Grok Bot (after Dipan's OK) · Needs: D4, 6.5, 7.4 · Status: Open
  - How: Terraform
  - Verify: `gcloud monitoring policies list` shows each with a channel
- [ ] **9.2** Dev parity: turn on dev monitoring (only the DLQ policy exists, 0 channels)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, D4 · Status: Open
  - How: Set `enable_platform_monitoring` and emails in dev tfvars, apply
  - Verify: Same check on lanonna-dev
- [ ] **9.3** Worker error alert
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19 · Status: Open
  - How: PR in `modules/platform/monitoring.tf`
  - Verify: Policy exists
- [ ] **9.4** Error notifications for api and worker via a log-based alert (Error Reporting's own toggle is console-only)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.4h · Status: Open
  - How: Terraform `google_monitoring_alert_policy` on `severity>=ERROR`
  - Verify: Policy fires on a test error log
- [ ] **9.5** Logs: 30-day `_Default`; invite-token exclusion
  - Owner: Grok Bot (after Dipan's OK) · Needs: 2.6 · Status: Open
  - How: Terraform
  - Verify: `gcloud logging sinks describe _Default` lists the exclusion
- [ ] **9.6** Crashlytics new-issue and velocity alerts
  - Owner: Dipan (console only) · Needs: M13, 8.10 · Status: Open
  - How: Firebase console → Project settings → Alerts
  - Verify: Test crash triggers mail
- [ ] **9.7** Cost baseline: 1 warm API instance, SQL 1 vCPU always on; review after week 1
  - Owner: Grok Bot (after Dipan's OK) · Needs: 1.3 · Status: Open
  - How: Budget status plus Cloud Run and SQL usage; you glance at Billing → Reports
  - Verify: Within budget

### Phase 10: Security and privacy

- [ ] **10.1** In-app Terms and Privacy are samples reachable only from onboarding; wire Settings and replace the copy after PR #351
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19, 13.3 · Status: Open
  - How: `apps/mobile/assets/legal/*.html`; `onboarding_complete_profile_screen.dart:503-504`
  - Verify: Settings opens the real text; no 'Sample'
- [ ] **10.2** Legal pages load Google Fonts; bundle or use system fonts
  - Owner: Grok Bot (after Dipan's OK) · Needs: 10.1 · Status: Open
  - How: Same PR
  - Verify: No external URL in `assets/legal`
- [ ] **10.3** Prod `SUPPORT_EMAIL` set in prod.json and guarded (fallback in `app_config.dart:151`)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D11, D19 · Status: Open
  - How: PR in `app_config.dart`, `flavors/prod.json`, guard tests
  - Verify: Prod build fails if unset
- [x] **10.4** No App Check debug token in prod builds
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Done
  - How: Gradle embeds it only for non-prod
  - Verify: Empty in prod BuildConfig
- [x] **10.5** No personal emails in prod config or the repo
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Done
  - How: `scripts/verify-no-personal-emails.sh` before every PR
  - Verify: Prints OK
- [ ] **10.6** Account deletion removes Storage files
  - Owner: Grok Bot (after Dipan's OK) · Needs: 6.6 · Status: Open
  - How: Exercise in 12.4
  - Verify: Objects gone; `storage_cleanup_completed` logged
- [x] **10.7** Rate limiting on; CORS empty
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Done
  - How: `middleware/rate_limit.py`, `config.py`
  - Verify: Unchanged in prod env
- [x] **10.8** Android backup off, no cleartext, release minified
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Done
  - How: `AndroidManifest.xml`, `build.gradle.kts`
  - Verify: Checked in 11.10
- [ ] **10.9** Processor agreements: Mailjet DPA now, new provider's DPA at the move
  - Owner: Dipan · Needs: M18 · Status: Open
  - How: Provider account settings
  - Verify: DPA on file

### Phase 11: Mobile release build

- [ ] **11.1** Upload keystore exists on the Mac (21 Oct) with `key.properties`; offline backup is yours
  - Owner: Dipan · Needs: M16 · Status: Partly
  - How: Password manager plus offline copy
  - Verify: Backup restored once
- [ ] **11.2** Play App Signing accepted at first upload
  - Owner: Dipan (console only) · Needs: M5 · Status: Open
  - How: Play Console → App integrity
  - Verify: Signing key 'Google-managed'
- [x] **11.3** versionCode must only go up (`build_stamp.sh` count drops after squash merges)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19 · Status: Done
  - How: PR: first-parent count of `origin/main` plus a local high-water mark
  - Verify: A lower code fails the build (done: #444 / PR #445, merged c12beba)
- [ ] **11.4** AAB build wrapper with the build stamp
  - Owner: Grok Bot (after Dipan's OK) · Needs: 11.3, D19 · Status: Open
  - How: Appbundle mode in `scripts/flutter_build_apk.sh`
  - Verify: `app-release.aab` produced; stamp guard passes
- [ ] **11.5** google-services.json per environment, copied by `APP_ENV`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 8.4, D19 · Status: Open
  - How: Wrapper copies `.dev` / `.prod` json
  - Verify: Each build logs its project
- [ ] **11.6** Fill prod.json: `API_BASE_URL`, `APP_LINK_HOST`, `GOOGLE_SIGN_IN_SERVER_CLIENT_ID`, `SUPPORT_EMAIL`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D8, D11, 7.2, 8.4 · Status: Open
  - How: `apps/mobile/flavors/prod.json`; placeholder guard
  - Verify: Prod build compiles
- [ ] **11.7** Obfuscate, upload Dart symbols, native symbol table
  - Owner: Grok Bot (after Dipan's OK) · Needs: 11.4, D19 · Status: Open
  - How: `--obfuscate --split-debug-info=build/symbols`; `firebase crashlytics:symbols:upload --app=<prodAppId> build/symbols`
  - Verify: Readable Dart frames on a test crash
- [x] **11.8** Build stamp keys in prod Crashlytics
  - Owner: Grok Bot (after Dipan's OK) · Needs: 11.4 · Status: Done
  - How: Existing guard
  - Verify: Keys visible
- [x] **11.9** Target SDK 36 (Play rule from 31 Aug 2026)
  - Owner: Grok Bot (after Dipan's OK) · Needs: 11.4 · Status: Done
  - How: Flutter default on the Mac
  - Verify: `bundletool dump manifest` shows 36
- [ ] **11.10** Merged-manifest permissions match Data safety; no `AD_ID`
  - Owner: Grok Bot (after Dipan's OK) · Needs: 11.4 · Status: Open
  - How: `bundletool dump manifest`
  - Verify: Only expected permissions
- [ ] **11.11a** Screenshots (no email address visible; skip account and manage-followers screens)
  - Owner: Grok Bot (after Dipan's OK) · Needs: D17 · Status: Open
  - How: Captured on the Mac's emulator from the prod-config build
  - Verify: Play sizes, approved by you
- [ ] **11.11b** App icon and feature graphic
  - Owner: Dipan · Needs: D17 · Status: Open
  - How: Provide or approve
  - Verify: 512 px icon, 1024×500 graphic

### Phase 12: Prod verification

- [ ] **12.1** Local gate for every PR
  - Owner: Grok Bot (after Dipan's OK) · Needs: — · Status: Open
  - How: `scripts/premerge_check.sh` and `--e2e` on the Mac
  - Verify: Green; results in the PR without emails or UIDs
- [ ] **12.2** Maestro P0 on dev with the release commit
  - Owner: Grok Bot (after Dipan's OK) · Needs: 12.1 · Status: Open
  - How: `--e2e` against lanonna-dev on the emulator
  - Verify: All P0 flows pass
- [ ] **12.3** Backend smoke on prod after parameterizing `infra-smoke-display-upload.sh`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19, 7.2 · Status: Open
  - How: PR, then run with a prod smoke account
  - Verify: Upload lands in `lanonna-prod-display`, thumbnail appears
- [ ] **12.4** Manual P0 on the Play internal-test install: sign-up and verify, Google sign-in, create baby, upload, invite email + App Link, push, export, delete, Crashlytics event
  - Owner: Dipan · Needs: M19, 13.4, 8.7 · Status: Open
  - How: Your phone; Grok Bot drives via adb if plugged in. `adb shell pm get-app-links com.lanonna.lanonna`
  - Verify: Every step passes; DLQ empty
- [ ] **12.5** Pre-launch report reviewed
  - Owner: Dipan (console only) · Needs: M10, 13.4 · Status: Open
  - How: Play Console → Pre-launch report
  - Verify: No crashes or policy flags
- [ ] **12.6** Merge or close QA plan PR #363
  - Owner: Dipan · Needs: D20 · Status: Open
  - How: GitHub
  - Verify: Decided
- [ ] **12.7** Restore drill: point-in-time clone, row counts, delete clone
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1, 3.5 · Status: Open
  - How: `gcloud sql instances clone lanonna-db lanonna-db-drill --point-in-time=<UTC> --project=lanonna-prod`
  - Verify: Counts match; clone deleted
- [ ] **12.8** Alert fire drill
  - Owner: Grok Bot (after Dipan's OK) · Needs: 9.1 · Status: Open
  - How: Temporary always-firing policy, then delete; you confirm the mail arrived
  - Verify: Mail received
- [ ] **12.9** App Check enforcement on once verified traffic is near 100 %
  - Owner: Grok Bot (after Dipan's OK) · Needs: D21, 8.8, 12.4 · Status: Open
  - How: PR flipping `APP_CHECK_ENFORCE=true`, redeploy
  - Verify: Play install works; sideload gets 401

### Phase 13: Play Console

- [ ] **13.1** Developer account verified; package registered for developer verification
  - Owner: Dipan (console only) · Needs: M1, M2, D10 · Status: Open
  - How: Play Console
  - Verify: No verification banner
- [ ] **13.2** Create the app
  - Owner: Dipan (console only) · Needs: M3 · Status: Open
  - How: Play Console → Create app
  - Verify: App appears
- [ ] **13.3** Legal: fill PR #351's blanks, lawyer review, deploy hosted pages
  - Owner: Grok Bot (after Dipan's OK) · Needs: D11, D12, D15, M17 · Status: Blocked
  - How: Grok Bot fills and deploys with the Hosting script; you do the review
  - Verify: Privacy URL loads publicly
- [ ] **13.4a** Build the first prod AAB
  - Owner: Grok Bot (after Dipan's OK) · Needs: 11.4, 11.6 · Status: Open
  - How: AAB wrapper on the Mac
  - Verify: AAB path handed to you
- [ ] **13.4b** First upload to internal testing, Play App Signing, copy signing fingerprints
  - Owner: Dipan (console only) · Needs: M5, M16 · Status: Open
  - How: Play Console → Internal testing; App integrity
  - Verify: Internal testers install from Play
- [ ] **13.4c** Register Play signing SHA-1/256 in Firebase, Hosting assetlinks and App Check
  - Owner: Grok Bot (after Dipan's OK) · Needs: 13.4b · Status: Open
  - How: `firebase apps:android:sha:create`, rerun 8.7, 8.8
  - Verify: assetlinks and SHA list show both
- [ ] **13.5** Store listing text, icon, feature graphic, screenshots, contact
  - Owner: Grok Bot (after Dipan's OK) · Needs: D11, D17; M4 or M8 · Status: Open
  - How: Play Developer API `edits.listings` and `edits.images` if M4; otherwise you paste (M8)
  - Verify: Listing saved
- [ ] **13.6** Privacy policy URL
  - Owner: Dipan (console only) · Needs: M7, 13.3 · Status: Open
  - How: App content → Privacy policy
  - Verify: Saved
- [ ] **13.7** Web page for account-deletion requests, then its URL in App content
  - Owner: Grok Bot (after Dipan's OK) · Needs: D19; M7 for the URL · Status: Open
  - How: Hosted page naming La Nonna, steps, retention
  - Verify: URL loads and matches Data safety
- [ ] **13.8** Data safety form (Grok Bot drafts from `docs/legal/data-inventory.md`)
  - Owner: Dipan (console only) · Needs: M7, 11.10 · Status: Open
  - How: App content → Data safety
  - Verify: Submitted; matches policy
- [ ] **13.9** Target audience 18+, IARC rating, no ads, Health apps and other declarations
  - Owner: Dipan (console only) · Needs: M7, D16 · Status: Open
  - How: App content
  - Verify: All sections green
- [ ] **13.10** Reviewer test account: Grok Bot creates it in prod Auth and stores the credentials for you; you paste them in App access
  - Owner: Grok Bot (after Dipan's OK) · Needs: M7, 12.4 · Status: Open
  - How: Firebase Admin / Auth REST; password generated, never printed
  - Verify: Reviewer reaches the main screens
- [ ] **13.11** Closed test 12+ testers for 14 days, then apply for production (personal account)
  - Owner: Dipan (console only) · Needs: M9, D10, D18 · Status: Open
  - How: Closed testing track
  - Verify: Dashboard shows requirement met
- [ ] **13.12** Staged rollout 10 % → 50 % → 100 %
  - Owner: Grok Bot (after Dipan's OK) · Needs: D22; M4 (else you click) · Status: Open
  - How: Play Developer API `edits.tracks.update` with `userFraction`
  - Verify: Crash-free and alert-free for 48 h per step

### Phase 14: After launch

- [ ] **14.1** First week: daily look at Crashlytics, Cloud Run 5xx, DLQ, email failures, budget
  - Owner: Grok Bot (after Dipan's OK) · Needs: 13.12 · Status: Open
  - How: Monitoring reads
  - Verify: Short daily note to you
- [ ] **14.2** Rollback: previous revision, halt rollout, force-update via `app_versions.minimum_version`
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1 (per incident) · Status: Open
  - How: `gcloud run services update-traffic api --to-revisions=<previous>=100 --region=us-central1 --project=lanonna-prod`
  - Verify: Tried once on a no-op revision
- [ ] **14.3** Quarterly restore drill
  - Owner: Grok Bot (after Dipan's OK) · Needs: 12.7 · Status: Open
  - How: Same as 12.7
  - Verify: Logged
- [ ] **14.4** Paging channel (you are on call)
  - Owner: Dipan (console only) · Needs: M20 · Status: Open
  - How: Mobile app or SMS channel
  - Verify: Test page received
- [ ] **14.5** Release routine: migrations → worker (+ IAM) → API, explicit `GCP_PROJECT_ID=lanonna-prod`, then smoke
  - Owner: Grok Bot (after Dipan's OK) · Needs: D1 · Status: Open
  - How: `operations.md` deploy order
  - Verify: Followed each release
- [ ] **14.6** Backlog: email move (6.8), regional HA Cloud SQL, iOS
  - Owner: Dipan · Needs: D13 · Status: Open
  - How: Decisions
  - Verify: —

## Runbook corrections

| Where | What's wrong | Fix |
|---|---|---|
| `apps/mobile/android/README.md` | Runs `flutter build appbundle` directly, skipping the build stamp | Point to the AAB wrapper (11.4) |
| `scripts/flutter_build_apk.sh` | APK only | Add an appbundle mode (11.4) |
| `docs/engineering/pre-prod-consolidation.md` | Says 41 migrations and a CI diff check | 52 migrations; no CI |
| `docs/engineering/operations.md` | Automation SA 'CI + WIF later' | No CI; deployer is your login on the Mac, run by Grok Bot's executors after your OK |
| `docs/engineering/operations.md` prod step 8 | Phase 2 edits tracked `main.tf` | Expose a variable (2.4a) |
| `docs/engineering/operations.md` prod step 5 | `admin-api-key` and postgres password optional | Both required (3.4, 4.3) |
| `infra/env/prod.api.env` | `APP_CHECK_ENFORCE=true` | false until 12.9 |
| `services/api/src/lanonna_api/config.py` | Silent dev defaults | Fail loudly (7.3) |
| `scripts/configure-android-google-sign-in.sh` | Hardcodes the dev app id and debug keystore | Don't use for prod; follow 8.2 |
| `scripts/infra-smoke-display-upload.sh` | Hardcodes the dev bucket and key | Parameterize (12.3) |
| `docs/engineering/mobile-prod-flavor-and-crashlytics.md` | One `google-services.json` path, no switch | Per-env copy (11.5) |
| `scripts/build_stamp.sh` docs | Mention `GITHUB_RUN_NUMBER` | No CI; local high-water mark (11.3) |

## Couldn't verify

- **Python 3.14 break in `delete_dev_account.sh`** — Not reproduced; dev-only
- **Whether lanonna-prod exists under another account** — Only checked with the Mac's gcloud login
- **Keystore backup** — Dipan to confirm (M16)
- **Cloud Build default identity in the new project** — See 2.8
- **Whether Crashlytics still needs a console Enable click** — No enable API found; M14 is conditional
- **Error Reporting notification API** — None found; replaced by a log-based alert (9.4)
- **SMTP2GO Starter price and 50k cost; Postmark 50k tier price** — Plan card and page title disagree ($10 vs $15); Postmark's slider tiers didn't render
- **Brevo prices** — Read from Brevo's own pricing API and pricing.md, not the rendered page
- **SES sandbox limits** — Known behavior, not on the pricing page
- **Health apps declaration trigger** — Answer in 13.9

## Review log

| Pass | Checked against | Added or corrected |
|---|---|---|
| Draft | Brief phases 0–14, `operations.md`, `pre-prod-consolidation.md`, Terraform, deploy scripts | First tracker |
| Pass 1 | Repo at 5ef8a75 file by file; read-only dev inventory; open PRs and issues | Added 1.5, 2.4, 3.4, 4.3, 7.3, 10.3, 11.4, 11.5, 12.3; corrected 048/049 ordering; marked notes |
| Pass 2 | Play Help pages; GCP practice; dependency order | Added 0.2, 0.9, 0.12, 13.1, 13.7, 11.7, 12.7, 12.9; moved SHA registration after the first upload |
| Pass 3 (25 Oct, Dipan's follow-up) | Ownership rule change; Firebase App Check REST, Identity Toolkit v2, gcloud billing / budgets / essential-contacts / api-keys, Play Developer API; official email pricing pages | Re-tagged every item (Grok Bot after Dipan's OK, Dipan, or console only); split 8.3, 11.11, 13.4; replaced console steps 1.3, 1.7, 8.5, 8.12, 9.4 with CLI/API; added the inputs list (D1–D23), manual list (M1–M22), console-settings table, 6.8–6.9 email move, Email provider options |
| Repo copy (25 Oct) | Converted to Markdown | Added registrar comparison and Mailjet-without-domain note; 11.3 marked done (PR #445) |

## Sources

- [Amazon SES pricing](https://aws.amazon.com/ses/pricing/)
- [Resend pricing](https://resend.com/pricing)
- [Brevo pricing (machine-readable)](https://www.brevo.com/pricing.md)
- [Mailgun pricing](https://www.mailgun.com/pricing/)
- [MailerSend pricing](https://www.mailersend.com/pricing)
- [SMTP2GO pricing](https://www.smtp2go.com/pricing/)
- [SendGrid Email API pricing](https://www.twilio.com/en-us/products/email-api/pricing)
- [Postmark pricing](https://postmarkapp.com/pricing)
- [Mailjet pricing update, 9 Sep 2026](https://documentation.mailjet.com/hc/en-us/articles/25750983876763-Mailjet-Subscription-Pricing-Update-September-9-2026)
- [Sending email from Google Cloud (port 25)](https://cloud.google.com/compute/docs/tutorials/sending-mail)
- [Mailgun via Google Cloud Marketplace](https://docs.cloud.google.com/compute/docs/tutorials/sending-mail/using-mailgun)
- [SendGrid on Google Cloud](https://www.twilio.com/docs/sendgrid/for-developers/partners/google)
- [App Check playIntegrityConfig REST](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.playIntegrityConfig)
- [Identity Toolkit projects.updateConfig](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/projects/updateConfig)
- [Google Play Developer API](https://developers.google.com/android-publisher)
- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Data safety section](https://support.google.com/googleplay/android-developer/answer/10144311)
- [User generated content policy](https://support.google.com/googleplay/android-developer/answer/9876937)
- [Android developer verification](https://support.google.com/googleplay/android-developer/answer/17134731)
- [PR #351 legal pages and store listing](https://github.com/dipan0saha/lanonna_app/pull/351)
- [PR #363 pre-prod QA plan](https://github.com/dipan0saha/lanonna_app/pull/363)
- [Operations runbook](operations.md)
