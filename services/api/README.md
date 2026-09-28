# La Nonna API (Python / FastAPI)

Cloud Run service **`api`** in `lanonna-dev`.

## Endpoints (dev)

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | Public |
| GET | `/v1/me` | Firebase Bearer JWT |
| GET | `/v1/profile` | Firebase Bearer JWT (upserts `app_users` in Cloud SQL) |

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
# Optional DB via Cloud SQL proxy + DB_PASSWORD
uvicorn lanonna_api.main:app --reload --app-dir src
```
