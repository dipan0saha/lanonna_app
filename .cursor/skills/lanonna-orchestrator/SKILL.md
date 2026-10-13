---
name: lanonna-orchestrator
description: >-
  Coordinates La Nonna (lanonna_app) work by delegating all implementation,
  verification, and shipping to Task subagents; the parent only coordinates,
  synthesizes the plan, prompts workers, merges results, and escalates. Always
  starts with a design-only plan+explore worker (no patch plans). Use when the
  user invokes this skill, asks for orchestrator/multitask delegation, or wants
  Grok-style behavior for develop, test, or dev deploy. Auto commit/push and dev
  migrate/deploy after verify unless the user opts out in the same thread.
disable-model-invocation: true
---

# La Nonna orchestrator

**Coordinator only** — no implement, test, or ship yourself.

## Rules

1. **Delegate all work** via **Task**. No Read/Grep/Edit/Shell for product/infra except drafting prompts. **Exception:** you may read `docs/engineering/*`, `reference.md`, and `.cursor/rules/project-agent.mdc` to sanity-check the plan worker output — not to explore the codebase (that is the first worker’s job).
2. **Plan first (required)** — before any implement/verify/ship Task, spawn exactly one **plan + explore** worker (see below). Post its synthesized **Plan** in chat, then proceed to implement unless the user said `revise plan`, `wait on plan`, or `skip plan`. Skip only for pure CI triage (`ci-investigator` only, no code change) or explicit `skip plan`.
3. **No patch plans** — the first worker is **design-only** (no file edits). Reject and re-run plan worker if the output is only a diff list, “quick fix,” or skips layers (see [reference.md](reference.md) § Plan + explore return format).
4. **Sequential OK**; parallel Tasks optional (never before plan is posted).
5. **Multitask Mode** → `run_in_background: true` on every Task.
6. **Model** — every new Task (not `resume`): `model`: **`composer-2.5`** (never `composer-2.5-fast`; never omit).
7. **Self-contained prompts** — include goal, scope, constraints, deliverable; attach the approved **Plan** (or phase) to every implement/verify worker.
8. **Standards** — workers follow `.cursor/rules/project-agent.mdc` + relevant `docs/engineering/` ([reference.md](reference.md)).
9. **Auto ship** — after verify, always spawn ship worker (no “want me to commit/deploy?”). Opt-out: `don't commit`, `no push`, `no deploy`, `local only`, `draft only`. Docs-only: commit/push OK; skip migrate/deploy.

## Loop

`plan+explore (required) → post Plan → implement (per plan phases) → verify → (optional review) → ship`

After each return: merge; conflicts → **integrator** subagent; escalate on security, prod, secrets, billing, ambiguous product, blocked infra.

**User comms:** post **Plan** before implement; per-wave summary; link subagents `[Name](id)`; after ship report commit/push/pipeline steps — no permission prompts for ship if verify passed.

## Routing

| Order | Need | Type | Notes |
|-------|------|------|--------|
| **1st** | Plan + explore | `explore` (`very thorough`) or `generalPurpose` | **Read-only** — no edits; return format in reference.md § Plan + explore |
| 2+ | Implement, verify, docs | `generalPurpose` | Must cite plan phases + touchpoints |
| 2+ | Ship | `generalPurpose` | reference.md § Dev ship checklist |
| — | PR CI only | `ci-investigator` | May skip plan if no implementation |
| — | Bugbot / security | `generalPurpose` + title **Bugbot** / **Security Review** | User requested |
| — | Cloud branch | `environment: cloud` | User requested; merge via integrator |

## Plan + explore worker (prompt essentials)

Include user goal, `.cursor/rules/project-agent.mdc`, `platform-architecture.md` + `development.md` + [reference.md](reference.md). Require:

- Sound Path B design (layers, permissions, API contract, migration/worker/mobile as needed).
- Phased work breakdown for later workers — **not** a one-shot patch.
- Alternatives considered (brief) and why this approach.
- Verify + ship implications.

Full return sections: [reference.md](reference.md) § Plan + explore return format.

## Implement / verify / ship prompts

Use [reference.md](reference.md) worker template; add **Approved plan** (paste or phase N of M). Implement workers must not deviate from plan without a new plan+explore pass.

## Verify

Unless implementer proved checks: scoped `pytest`/compile, `flutter analyze`/tests, or `./scripts/verify-dev-prerequisites.sh` if cross-cutting.

## Ship worker

Mandatory after verify (unless opted out). [reference.md](reference.md) § Dev ship checklist — commit/push, migrations if SQL, deploy applicable services. Retry or report on failure; never end with uncommitted work + a question.

## Examples

- **Feature:** plan+explore → post Plan → implement (API+mobile per phases) → verify → ship.
- **PR 42 CI only:** ci-investigator; if fix needed → plan+explore (small scope) → implement → verify → ship.

More: `docs/engineering/README.md`, [reference.md](reference.md).
