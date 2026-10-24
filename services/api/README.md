# La Nonna API (Python / FastAPI)

Cloud Run service **`api`** in `lanonna-dev`.

**Canonical route list:** [docs/engineering/development.md](../../docs/engineering/development.md).

**Layout:** `src/lanonna_api/` — `routers/` (thin HTTP) → `domain/` (rules, permissions) → `repositories/` (parameterized SQL only). Shared pieces: `http_errors.map_domain_errors` (domain errors → 400/403/404/409; e.g. `domain/fun_closed.FunWritesClosedError` → 409), `pagination.py` (`{items, offset, limit, has_more}` envelope for every list route) with SQL paging in `repositories/_paging.py`. Conventions: [platform-architecture.md §2.3](../../docs/engineering/platform-architecture.md#23-api-internal-layering-single-cloud-run-service).

## Deploy

```bash
gcloud config set account <your-deploy-account>
# GCP_PROJECT_ID defaults to lanonna-dev; use GCP_PROJECT_ID=lanonna-prod for prod.
GCP_PROJECT_ID=lanonna-dev ./scripts/deploy.sh
```

Uses **Cloud Build** by default (`USE_LOCAL_DOCKER=1` if you have Docker).

## Local run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export ENVIRONMENT=dev GCP_PROJECT_ID=lanonna-dev
# Optional DB via Cloud SQL proxy + DB_PASSWORD (see .env.example)
uvicorn lanonna_api.main:app --reload --app-dir src
```

## Tests

```bash
PYTHONPATH=src pytest -q
```

Integration tests (`tests/integration/`) need local Postgres on 5432: `docker compose -f docker-compose.test.yml up -d` from the repo root. The local pre-merge gate runs unit + integration tests ([`scripts/premerge_check.sh`](../../scripts/premerge_check.sh)).
