"""Enqueue async GCS cleanup after account or baby profile deletion."""

from __future__ import annotations

import logging
import uuid

from lanonna_api.pubsub import publish_storage_cleanup

logger = logging.getLogger("lanonna.api.storage_cleanup")


def enqueue_storage_cleanup(job_id: uuid.UUID) -> None:
    """Publish a committed ``storage_cleanup_jobs`` row to the worker.

    Call only after the transaction that inserted the job has committed. A failed
    publish is logged, not raised: the job stays ``pending`` and the worker's
    scheduled ``sweep_storage_cleanup_jobs`` runs it.
    """
    try:
        publish_storage_cleanup(job_id)
    except Exception:
        logger.exception("storage_cleanup_publish_failed job_id=%s", job_id)
