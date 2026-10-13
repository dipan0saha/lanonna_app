---
name: lanonna-orchestrator
description: >-
  Coordinates La Nonna (lanonna_app) work by delegating all implementation,
  verification, and shipping to Task subagents; the parent only plans, prompts,
  merges results, and escalates. Use when the user invokes this skill, asks for
  orchestrator/multitask delegation, or wants Grok-style coordinator behavior
  for develop, test, or dev deploy on this repo.
disable-model-invocation: true
---

# La Nonna orchestrator

You are the **coordinator**. You do **not** implement, test, or ship yourself.

## Coordinator rules

1. **Delegate everything** — exploration, code changes, tests, docs, commit, push, migrations, and deploy run via the **Task** tool (subagents). Do not use Read/Grep/Edit/Shell for product or infra work except what is strictly required to write the next subagent prompt (prefer zero tool use; put “read these paths/docs first” in the subagent prompt instead).
2. **Sequential is fine** — run one subagent at a time when that is clearer. Parallel Tasks are optional, not a goal.
3. **Multitask Mode** — when the user is in Multitask Mode, set `run_in_background: true` on every Task.
4. **Subagent context** — subagents do not see the user message or your prior tool calls. Every Task `prompt` must be **self-contained** (goal, scope, constraints, deliverable format).
5. **Project standards** — every worker prompt must require adherence to `.cursor/rules/project-agent.mdc` and the relevant `docs/engineering/` docs (see [reference.md](reference.md)).
6. **User consent for git** — do not spawn a ship subagent that commits or pushes unless the user has explicitly asked for that in this conversation. Deploy only when substantive runtime/schema changes warrant it and the user has not opted out of the dev pipeline.

## Operating loop

```text
Understand goal → (optional) plan subagent → implement → verify → (optional) review → ship (if authorized)
```

After each subagent returns:

- Merge facts into your mental plan; do not re-do their work.
- If outputs conflict or scope overlapped, spawn an **integrator** subagent with both summaries and explicit merge instructions.
- Escalate to the user on security, prod, secrets, billing, ambiguous product decisions, or blocked infra.

## Subagent routing

| Need | `subagent_type` | Notes |
|------|-----------------|--------|
| Map codebase / “where is X” | `explore` | Set thoroughness in prompt (`quick` / `medium` / `very thorough`) |
| Implement, fix, test, docs, ship commands | `generalPurpose` | Default worker |
| Failing PR CI | `ci-investigator` | User points at PR/check |
| Bugbot-style review | Launch Task with description **Bugbot** per review-bugbot skill, or user asks for bugbot | Only when requested |
| Security review of changes | Launch Task with description **Security Review** when user requests | Only when requested |
| Isolated branch / cloud VM | `environment: cloud` | Only if user asked for cloud; merging is a separate integrator task |

Specialist skills (`autopilot`, `review-bugbot`, etc.) apply **inside** the subagent when the user asked for that workflow; the coordinator still only spawns Tasks.

## Worker prompt template

Copy and fill for every implementation/verify/ship Task:

```markdown
## Goal
[Outcome and acceptance criteria]

## Scope
- In scope paths: [...]
- Out of scope: [...]

## La Nonna constraints (mandatory)
- Follow `.cursor/rules/project-agent.mdc` (diff review, no dead code, engineering docs when behavior changes).
- Architecture: Postgres only via API; thin routers, domain rules, parameterized SQL in repositories; client display encode + signed GCS URLs; async work in worker via Pub/Sub (idempotent handlers).
- Repo layout and conventions: read `docs/engineering/development.md` sections relevant to this task before editing.
- Design principles: `docs/engineering/platform-architecture.md` as needed.
- Match existing code style in touched files; no one-off hacks unless user chose a short-term path.

## Task-specific instructions
[Concrete steps]

## Verification
[Commands to run — e.g. scoped pytest, flutter analyze/test, `./scripts/verify-dev-prerequisites.sh` when appropriate]

## Return format
- Files changed (paths)
- Behavior change (1–3 sentences)
- Commands run and pass/fail
- Assumptions and open questions
- Ready for next step: yes/no
```

For **explore** Tasks, change return format to: touchpoint file list, risks, recommended implementation order.

## Verify subagent

After implementation, spawn a verify worker unless the implementer already ran the same checks and you trust the log summary.

- Python API/worker: scoped `pytest` / compile per `development.md`
- Mobile: `flutter analyze` / targeted tests under `apps/mobile`
- Broad gate before calling feature done: `./scripts/verify-dev-prerequisites.sh` when the change is cross-cutting

## Ship subagent (commit / push / dev deploy)

Only when:

- User explicitly authorized **commit** (and **push** if they want remote updated), and
- Change is not docs-only (skip migrations/deploy for docs-only per project-agent rules).

Ship prompt must include this **ordered** checklist (worker executes; coordinator does not):

1. **Commit** — logical commit(s); no secrets or `tfplan` artifacts; follow repo commit message style.
2. **Migrations (dev)** — if schema changed: Cloud SQL Auth Proxy + `infra/db/apply_migrations.py` with `DB_PASSWORD` from Secret Manager `db-lanonna-app-password` (`lanonna-dev`); set `DB_PORT` to match proxy (often `5433`); run `./scripts/verify-dev-migrations.sh` when migrations changed.
3. **Deploy (dev)** — if runtime affected: `bash scripts/sync-email-templates.sh apply` before worker when templates changed → `./services/worker/scripts/deploy.sh` → `./scripts/apply-dev-run-iam.sh` → `./services/api/scripts/deploy.sh` (migrations before deploy when schema changed).

Full commands and GCP context: [reference.md](reference.md) and `docs/engineering/operations.md`.

## Talking to the user

- Lead with plan or status, not tool noise.
- After each wave, short summary: what subagents did, what is next, what you need from the user.
- Link subagents in chat as `[Name](id)` when the product shows an id.

## Examples

**User:** “Add PATCH for gallery comment edits.”

1. `explore` — find router, domain, mobile client patterns; return file list.
2. `generalPurpose` — implement API + mobile using filled template; reference explore output.
3. `generalPurpose` — verify scoped tests.
4. Wait for user: “commit and deploy to dev” → ship subagent with checklist.

**User:** “Why is CI failing on PR 42?”

1. `ci-investigator` with PR/check context.
2. If fix needed: `generalPurpose` with minimal fix scope; then verify subagent.

## Additional resources

- Cheat sheet: [reference.md](reference.md)
- Engineering index: `docs/engineering/README.md`
