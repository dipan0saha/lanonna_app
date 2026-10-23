# RCA: No dev invite emails after the worker-00042 deploy; every Mailjet send fails with "Connection reset by peer" (#428)

## Summary

On lanonna-dev, no invite email was delivered between 17:51 UTC and 20:01 UTC on 2026-10-23. Every send from the worker failed with `httpx.ConnectError: [Errno 104] Connection reset by peer`. Invitations stayed `pending` while Pub/Sub redelivered them, and some became `failed` once their retries ran out. The failures started at the first send after `worker-00042-fjm` (built from #416) went live, so the new image was the first suspect.

## Investigation

| Check | Result |
|-------|--------|
| Revision spec, `worker-00041-ljd` vs `worker-00042-fjm` | Identical apart from the image digest: same env vars, secrets, service account, Cloud SQL attachment, scaling and probes. Neither revision has a VPC connector or egress setting, and the project has no Cloud NAT or router. Egress is Cloud Run's default shared Google egress, so there is no static IP for Mailjet to allowlist, and none was ever configured. |
| Image contents, run on Cloud Build | Same Debian 13 base, Python 3.12.15, OpenSSL 3.5.7 and `httpx` 0.28.1. `pip freeze` differs in only one line: `certifi` 2026.10.19 → 2026.10.23. Both images get `401` from an unauthenticated `POST https://api.mailjet.com/v3.1/send`, so TLS and HTTP work. |
| Both images as Cloud Run jobs (worker service account, default egress) | Both images complete DNS, TCP and the TLS 1.3 handshake to Mailjet and get `401`. Other outbound HTTPS from both images works too (google.com, api.github.com, httpbin, ipify). |
| Worker logs by instance | All 80 `mailjet_send_failed` lines came from **one instance** of `worker-00042-fjm`. It started at 18:09:54 UTC, failed every Mailjet handshake about 250 ms in, from its first send at 18:10:18 until it was stopped at 20:01:28, and failed nothing else. Its Pub/Sub, Cloud SQL and GCS traffic (thumbnails, cleanup sweeps) kept working the whole time. |
| Traffic moved to `worker-00041-ljd` (20:01 UTC) | A new instance sent the queued invites within 20 s. |
| Traffic moved back to `worker-00042-fjm` (20:09 UTC) | A **new instance of the same image** sent a fresh invite on the first attempt (20:11:44 UTC), and it was delivered to the QA test inbox. |

## Root cause

The image is not at fault. The one `worker-00042-fjm` instance that served all traffic lost its outbound path to Mailjet: every TCP/TLS connection to `api.mailjet.com` was reset during the handshake. Its other traffic was unaffected, and new instances on either revision connected normally. It is not possible to say from inside our project whether the reset came from the instance's egress path or from Mailjet's edge treating that instance's egress address differently. Either way, the fault was tied to that instance's network path and lasted as long as the instance did.

The outage lasted almost two hours because nothing in our system could tell that the instance was broken:

1. **No liveness signal.** The worker only had Cloud Run's default TCP startup probe. The instance kept accepting requests and answering 500 (the intended "retry later" signal to Pub/Sub), so Cloud Run treated it as healthy.
2. **Steady traffic kept the broken instance alive.** Pub/Sub redeliveries, cron pushes and GCS events kept that single instance warm (`min-instances=0`, low volume), so autoscaling never replaced it.
3. **Retries went to the same place.** Pub/Sub backoff and redelivery worked as designed, but every retry landed on the same instance, so retrying alone could never succeed.
4. **No alert.** The 5xx alert covers only the API service, and nothing watched worker send failures. QA found the problem by hand.

#416, the base image and the dependency versions are not the cause. The timing matched only because the deploy created a new instance.

## Fix

The fix makes the worker detect a broken network path to Mailjet and get the instance replaced, and it alerts when sends fail.

| Layer | Change |
|-------|--------|
| `lanonna_worker/egress_health.py` (new) | `EgressHealth` tracks consecutive **connect-stage** failures to a destination. It reports unhealthy only when there are at least 5 failures in a row and the first is at least 120 s old, with no successful connection in between. Any HTTP response, even a 4xx or 5xx, proves the path works and resets the count. |
| `lanonna_worker/mailjet_send.py` | `send_messages`, the only Mailjet send path, records `ConnectError`/`ConnectTimeout` as failures and any response as success, then re-raises as before. Invite retry handling is unchanged. The timeout is now `httpx.Timeout(30, connect=10)`, so a stalled connect fails within 10 s instead of 30. |
| `lanonna_worker/main.py` | `GET /health/live` returns 503 and logs `egress_unhealthy destination=mailjet ...` while the tracker is unhealthy, and 200 otherwise. It avoids paths ending in `z`, which Cloud Run reserves. |
| `services/worker/scripts/deploy.sh` | Deploys an HTTP liveness probe on `/health/live` (period 30 s, threshold 2). When the probe fails, Cloud Run stops that instance and starts a new one. Unacked invites go back to Pub/Sub and are sent from the new instance. |
| Terraform `monitoring.tf` | A log-based metric `worker_mailjet_send_failed` and an alert when there are more than 5 failures in 15 minutes. Like the other alerts, it is gated by `enable_platform_monitoring`. |

Worst-case recovery time for one broken instance is now about 3 minutes (120 s of failures plus two 30 s probe periods), down from "until someone notices."

**A real Mailjet outage** looks the same to every instance, so instances would be replaced every few minutes. That costs only cold starts, Cloud Run rate-limits liveness restarts, and the new alert reports the outage. Restarting cannot hide a real outage, because invites keep their `pending`/`failed` status and their `email_last_error`.

**Not changed:** the base image and dependency pins. They were ruled out above. Pinning the base image digest and transitive dependencies would make builds reproducible, but it would not have prevented this outage.

## Recovery

- Invites that were still pending were sent once a healthy instance was serving (20:01 UTC onward).
- Invites already marked `failed` need a resend. The owner can tap **Resend** in Manage followers, which calls `POST /v1/babies/{id}/invitations/{invitation_id}/resend`. Resend was confirmed working on the fixed worker.

## References

- GitHub #428
- `services/worker/src/lanonna_worker/egress_health.py`
- `services/worker/src/lanonna_worker/mailjet_send.py`
- `services/worker/scripts/deploy.sh`
- `infra/terraform/modules/platform/monitoring.tf`
- Cloud Run health checks: https://cloud.google.com/run/docs/configuring/healthchecks
