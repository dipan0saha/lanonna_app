# GCP / Firebase

**Live dev project:** `lanonna-dev` — see **[SETUP.md](SETUP.md)** for resources, service accounts, and manual Firebase steps.

| File | Purpose |
|------|---------|
| [SETUP.md](SETUP.md) | What is provisioned, console links, automation key path |
| [project.env.example](project.env.example) / `project.env` | Reference list of resource names (kept as an inventory; nothing sources it — the legacy `bootstrap.sh` was removed and [Terraform](../terraform/environments/dev) provisions everything) |

Architecture: [docs/engineering/platform-architecture.md](../../docs/engineering/platform-architecture.md).
