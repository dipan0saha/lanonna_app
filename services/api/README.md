# API service (Cloud Run)

HTTP surface for La Nonna: Firebase JWT verification, App Check, baby/membership authorization, CRUD, signed GCS URLs for `display/` uploads and reads.

## Planned layout

```
services/api/
├── Dockerfile
├── .env.example
└── src/                 # Language TBD — keep handlers thin
    ├── http/            # Routes + middleware
    ├── domain/          # Business rules (shared with worker where possible)
    ├── repositories/    # SQL access
    └── adapters/        # GCS signing, Pub/Sub publish, EmailSender
```

Migrations live in `infra/db/migrations/`, not in this folder.

## Operations

- **Service name:** `api` (Cloud Run)
- **Min instances:** 0 (scale on demand)
- **Auth:** `Authorization: Bearer <Firebase ID token>`; App Check header before public beta

See [docs/path_b_gcp_stack.md](../../docs/path_b_gcp_stack.md).
