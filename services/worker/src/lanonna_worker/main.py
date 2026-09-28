import base64
import json
import logging
from typing import Any

from fastapi import FastAPI, Request, Response

from lanonna_worker.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("lanonna.worker")

app = FastAPI(title="La Nonna Worker", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.post("/pubsub/push")
async def pubsub_push(request: Request) -> Response:
    """Pub/Sub push delivery stub (ack by returning 2xx)."""
    body: dict[str, Any] = await request.json()
    message = body.get("message", {})
    raw = message.get("data", "")
    payload: dict[str, Any] = {}
    if raw:
        try:
            payload = json.loads(base64.b64decode(raw).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            payload = {"raw": raw}
    bucket = payload.get("bucket")
    name = payload.get("name")
    if bucket and name:
        logger.info(
            "gcs_object_finalized message_id=%s bucket=%s name=%s",
            message.get("messageId"),
            bucket,
            name,
        )
    else:
        logger.info(
            "pubsub message_id=%s subscription=%s payload=%s",
            message.get("messageId"),
            body.get("subscription"),
            payload,
        )
    return Response(status_code=204)
