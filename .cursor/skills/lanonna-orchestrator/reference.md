# La Nonna orchestrator — reference

Subagents should read the linked docs; coordinators paste the **Constraints** bullets into every Task prompt.

## Repository map

```
lanonna_app/
├── apps/mobile/           # Flutter (feature-first under lib/features/)
├── services/api/          # Cloud Run HTTP API
├── services/worker/       # Cloud Run Pub/Sub worker
├── packages/email-templates/
├── infra/db/migrations/   # SQL migrations (lexicographic order)
├── infra/terraform/       # GCP platform (dev/prod)
├── scripts/               # verify, IAM, smoke, ship APK
└── docs/engineering/      # development, operations, architecture, QA
```

## Architecture bullets (stable)

Paste into worker prompts when touching runtime behavior:

1. **Postgres never on client** — JWT API, baby-scoped permissions, server-side checks.
2. **API layering** — `routers/` → `domain/` → `repositories/` (parameterized SQL only).
3. **Media** — client encodes display asset; API mints signed URLs; GCS upload; worker thumbs + async side effects via Pub/Sub.
4. **Async** — idempotent worker handlers; claims committed with side effects (see `platform-architecture.md`).
5. **Secrets** — Secret Manager only; not in app or images.
6. **Region** — `us-central1`; dev project `lanonna-dev`.
7. **Two Run services** — deploy `api` and `worker` separately; worker not public (`apply-dev-run-iam.sh`).

## Mobile pointers

- Features: `apps/mobile/lib/features/` — see module table in `development.md`.
- Routes: `core/router/app_router.dart`; bootstrap/repos in `bootstrap.dart`.
- Dev run: `cd apps/mobile && flutter run --dart-define-from-file=flavors/dev.json`.
- Display names: API `users_display` helpers — never label from email.

## API pointers

- Package root: `services/api/src/lanonna_api/`.
- Public health: `GET /health` (no JWT).

## Worker pointers

- Push handler, async commands, email/FCM/export — see `operations.md` worker section.
- Email templates: `packages/email-templates/` — sync before worker deploy when changed.

## Dev ship checklist (subagent executes)

From `.cursor/rules/project-agent.mdc` + `operations.md`:

| Step | When | Action |
|------|------|--------|
| Commit/push | User asked | No secrets, no `tfplan` |
| Migrations | New/changed SQL in `infra/db/migrations/` | Proxy + `DB_PASSWORD` from SM `db-lanonna-app-password`; `infra/db/apply_migrations.py`; `DB_PORT` matches proxy (often **5433** for verify scripts; align with proxy); `./scripts/verify-dev-migrations.sh` |
| Email templates | Template changes | `bash scripts/sync-email-templates.sh apply` **before** worker |
| Worker | Worker/runtime change | `./services/worker/scripts/deploy.sh` |
| IAM | After worker deploy | `./scripts/apply-dev-run-iam.sh` |
| API | API/runtime change (after migrations if schema changed) | `./services/api/scripts/deploy.sh` |

**Order when multiple apply:** migrations → (email templates if needed) → worker → IAM → API.

**GCP account (dev deploys):** `lanonnaapp@gmail.com`, project `lanonna-dev`.

**Quality gates:** `./scripts/verify-dev-prerequisites.sh`; `pytest` when Python changes; Flutter analyze/test for mobile.

## Docs to cite by task type

| Task type | Read first |
|-----------|------------|
| Any feature | `development.md` |
| Deploy / SQL / Terraform | `operations.md` |
| Design / security posture | `platform-architecture.md` |
| Manual QA | `pre-beta-qa.md` |
| Known gaps | `open-gaps.md` |

## Coordinator do-not

- Do not commit, push, migrate, or deploy from the parent agent.
- Do not implement “quick fixes” after a subagent — spawn integrator or fixer subagent.
- Do not skip user authorization for git remote changes.
