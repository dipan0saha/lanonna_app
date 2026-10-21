# RCA: Public repo personal emails and invite-hosting deploy IAM failure

| Field | Value |
|-------|--------|
| **Status** | Fixed (repo scrub + script/Terraform cleanup; git history unchanged) |
| **Date** | 2026-10-21 |

## Summary

The repository is public. Tracked files contained the dev Mailjet sender address, operator Google accounts used for local deploys, and a personal Google Drive path default. Separately, `scripts/deploy-invite-hosting.sh` exited non-zero after a successful Firebase Hosting release when granting `roles/run.invoker` to a Firebase Hosting service account that does not exist in `lanonna-dev`.

## 1. Personal email addresses in git

### Symptoms

Roughly nineteen occurrences of personal Gmail addresses in tracked sources: `infra/env/dev.worker.env`, worker tests/docs, `docs/engineering/operations.md`, setup READMEs, and `scripts/copy_release_apk_to_drive.sh` (operator Drive path).

### Root cause

Dev deploy convenience: the validated Mailjet sender and the human `gcloud`/`firebase` account were documented inline so a fresh clone could deploy without extra local files. That is inappropriate for a public repo.

### Fix

- **Docs and tests:** neutral placeholders (`sender@example.com`, `operator@example.com`, `@test.com` QA patterns).
- **Runtime dev sender:** `MAILJET_FROM_EMAIL` moves to gitignored `infra/env/dev.worker.local.env`, with committed `infra/env/dev.worker.local.env.example`. Deploy resolves the sender as exported shell value > local file > committed `dev.worker.env` and **fails fast** if it is still missing.
- **CI:** `scripts/verify-no-personal-emails.sh` (also exercised from API tests) scans every tracked file as bytes (including encoded `%40` / `&#64;` forms) and fails on consumer mail providers (Gmail, Yahoo, Outlook/Hotmail/Live, iCloud, Proton, GMX, … with regional suffixes), agent inbox domains, and non-role addresses on `lanonna.app`. Findings print path, line and domain only, never the local part.

### Git history

Rewriting history (filter-repo / BFG) would remove addresses from old commits but requires a **force-push** and coordination with all clones. That has **not** been done. Operators who need a clean public history can run a history rewrite later with explicit approval.

## 2. Invite hosting deploy IAM step

### Symptoms

`bash scripts/deploy-invite-hosting.sh` completes `firebase deploy --only hosting`, then fails on:

```text
gcloud run services add-iam-policy-binding api …
serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-firebasehosting.iam.gserviceaccount.com
```

### What the step was for

[`hosting/firebase.json`](../../../hosting/firebase.json) rewrites `GET /v1/invitations/preview` to Cloud Run service `api` in `us-central1`. The script tried to grant that Google-managed principal `roles/run.invoker` on `api`, assuming Hosting invokes Cloud Run with that identity.

### Root cause

1. **Wrong or absent principal:** In `lanonna-dev`, `service-${PROJECT_NUMBER}@gcp-sa-firebasehosting.iam.gserviceaccount.com` is not a provisioned service account, so `add-iam-policy-binding` fails even though Hosting already published.
2. **Redundant for this project:** Firebase’s Cloud Run rewrite docs assume the target service allows **unauthenticated** invocation. La Nonna’s API is deployed with `--allow-unauthenticated` for the public preview route; `allUsers` already has `run.invoker`. The extra Hosting SA binding is not required for the rewrite to work.

### Fix

Remove the post-deploy IAM grant from `deploy-invite-hosting.sh`. Document that the preview rewrite depends on API remaining publicly invokable at the Cloud Run layer (app-layer auth unchanged). No Terraform binding for the non-existent Hosting SA.

## 3. Related cleanups (same PR)

| Item | Root cause | Fix |
|------|------------|-----|
| API `deploy.sh` sets global `gcloud config project` | Legacy pattern before `--project` on each command | Use `--project` per `gcloud` call (worker/scheduler already do) |
| `env_file.sh` shellcheck SC2163 | `printf -v` + `export` on a dynamic name | Assign with `export "${key}=${value}"` |
| Prod SQL password in Terraform state | `random_password` + `database_url` local embed the secret in state | Document risk in `open-gaps.md`; stop managing unused `database-url` secret **versions** in Terraform |
| Dev `database-url` secret | Legacy monolithic URL format; Cloud Run uses discrete `DB_*` + `db-lanonna-app-password` | Dropped from module default; dev `secret_ids` override keeps container in TF (M-61) |
