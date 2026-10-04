# La Nonna API (Python / FastAPI)

Cloud Run service **`api`** in `lanonna-dev`.

**Canonical route list:** [docs/engineering/development.md](../../docs/engineering/development.md).

**Layout:** `src/lanonna_api/` — `routers/`, `domain/`, `repositories/`.

## Deploy

```bash
gcloud config set account lanonnaapp@gmail.com
gcloud config set project lanonna-dev
./scripts/deploy.sh
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
