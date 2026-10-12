"""Compare and plan Firebase Auth email branding.

``%APP_NAME%`` in Firebase's default templates is the OAuth brand
application title (Firebase Console → Project settings → Public-facing name).
It is not the GCP project name and not the Firebase display name. Those two
are still set to "La Nonna" so the console matches the product, but check-remote
fails until the public-facing name itself is La Nonna.

Subject and HTML body updates can return EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED.
That lock is on Google's side; see scripts/firebase-auth-template-support-request.md.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

PUBLIC_NAME = "La Nonna"
SENDER_DISPLAY_NAME = "La Nonna"

TEMPLATE_SPECS: dict[str, dict[str, str]] = {
    "verifyEmailTemplate": {
        "subject_file": "verify_email.subject",
        "body_file": "verify_email.html",
        "body_marker": "Verify my email",
    },
    "resetPasswordTemplate": {
        "subject_file": "reset_password.subject",
        "body_file": "reset_password.html",
        "body_marker": "Reset my password",
    },
}

_CONSOLE_PUBLIC_NAME = (
    "Firebase Console → Project settings (gear) → General → Public-facing name → "
    "La Nonna → Save. That field is created when Google sign-in is enabled "
    "(Authentication → Sign-in method → Google → Enable, set the public-facing "
    "name and a support email you control). It is the value of %APP_NAME%. "
    "The GCP project name and the Firebase display name are separate and are "
    "not enough."
)


@dataclass(frozen=True)
class LocalTemplates:
    subjects: dict[str, str]
    bodies: dict[str, str]
    markers: dict[str, str]


def template_dir(root: Path | None = None) -> Path:
    if root is None:
        root = Path(__file__).resolve().parents[1]
    return root / "packages" / "firebase-auth-email-templates"


def load_templates(root: Path | None = None) -> LocalTemplates:
    directory = template_dir(root)
    subjects: dict[str, str] = {}
    bodies: dict[str, str] = {}
    markers: dict[str, str] = {}
    for key, spec in TEMPLATE_SPECS.items():
        subjects[key] = (directory / spec["subject_file"]).read_text(encoding="utf-8").strip()
        bodies[key] = (directory / spec["body_file"]).read_text(encoding="utf-8")
        markers[key] = spec["body_marker"]
    return LocalTemplates(subjects=subjects, bodies=bodies, markers=markers)


def local_errors(templates: LocalTemplates) -> list[str]:
    errors: list[str] = []
    for key, spec in TEMPLATE_SPECS.items():
        subject = templates.subjects.get(key, "")
        body = templates.bodies.get(key, "")
        marker = templates.markers[key]
        if "La Nonna" not in subject or "La Nonna" not in body:
            errors.append(f"{spec['subject_file']} and {spec['body_file']} must mention La Nonna.")
        if "%LINK%" not in body:
            errors.append(f"{spec['body_file']} must contain %LINK%.")
        if marker not in body:
            errors.append(f"{spec['body_file']} must contain the CTA {marker!r}.")
    return errors


def brand_action(existing_title: str | None) -> str:
    """What to do with the OAuth brand that supplies %APP_NAME%.

    ``ok`` — already La Nonna.
    ``patch`` — a brand exists and its title should be updated.
    ``console`` — no brand yet. Do not create one with the IAP brands API:
    API-created brands are internal-only and can break public Google sign-in.
    """
    if existing_title is None:
        return "console"
    if existing_title.strip() == PUBLIC_NAME:
        return "ok"
    return "patch"


def _template(config: dict[str, Any], key: str) -> dict[str, Any]:
    send_email = (config.get("notification") or {}).get("sendEmail") or {}
    template = send_email.get(key) or {}
    return template if isinstance(template, dict) else {}


def subject_branded(subject: str, *, desired: str, brand_title: str | None) -> bool:
    text = subject.strip()
    if text == desired:
        return True
    return "%APP_NAME%" in text and (brand_title or "").strip() == PUBLIC_NAME


def body_branded(body: str, *, marker: str) -> bool:
    return bool(body) and marker in body and "%LINK%" in body and "La Nonna" in body


def remote_errors(
    *,
    config: dict[str, Any],
    templates: LocalTemplates,
    brand_title: str | None,
    gcp_project_name: str | None,
    firebase_display_name: str | None,
) -> list[str]:
    """Problems a check-remote run should print. Empty means branding matches."""
    errors: list[str] = []
    if (gcp_project_name or "").strip() != PUBLIC_NAME:
        errors.append(
            f"GCP project name is {gcp_project_name!r}; expected {PUBLIC_NAME!r} "
            "(member-facing name only; this is not %APP_NAME%)."
        )
    if (firebase_display_name or "").strip() != PUBLIC_NAME:
        errors.append(
            f"Firebase display name is {firebase_display_name!r}; expected {PUBLIC_NAME!r}."
        )
    if brand_action(brand_title) != "ok":
        shown = brand_title if brand_title is not None else "(not set)"
        errors.append(
            f"Public-facing name (%APP_NAME%) is {shown!r}; expected {PUBLIC_NAME!r}. "
            + _CONSOLE_PUBLIC_NAME
        )
    for key in TEMPLATE_SPECS:
        remote = _template(config, key)
        sender = (remote.get("senderDisplayName") or "").strip()
        if sender != SENDER_DISPLAY_NAME:
            errors.append(
                f"{key} senderDisplayName is {sender or '(empty)'!r}; "
                f"expected {SENDER_DISPLAY_NAME!r}."
            )
        subject = remote.get("subject") or ""
        if not subject_branded(
            subject, desired=templates.subjects[key], brand_title=brand_title
        ):
            errors.append(
                f"{key} subject is not the La Nonna template and %APP_NAME% "
                "is not the public-facing name."
            )
        if not body_branded(remote.get("body") or "", marker=templates.markers[key]):
            errors.append(
                f"{key} body is not the branded HTML from "
                f"{TEMPLATE_SPECS[key]['body_file']}. If apply returned "
                "EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED, Firebase is blocking the "
                "template write. File the support request in "
                "scripts/firebase-auth-template-support-request.md."
            )
    return errors


def plan_patches(config: dict[str, Any], templates: LocalTemplates) -> list[dict[str, Any]]:
    """Idempotent Identity Toolkit patches. Skips fields that already match."""
    patches: list[dict[str, Any]] = []
    for key in TEMPLATE_SPECS:
        remote = _template(config, key)
        prefix = f"notification.sendEmail.{key}"
        if (remote.get("senderDisplayName") or "").strip() != SENDER_DISPLAY_NAME:
            patches.append(
                {
                    "update_mask": f"{prefix}.senderDisplayName",
                    "body": {
                        "notification": {
                            "sendEmail": {key: {"senderDisplayName": SENDER_DISPLAY_NAME}}
                        }
                    },
                }
            )
        if (remote.get("subject") or "").strip() != templates.subjects[key]:
            patches.append(
                {
                    "update_mask": f"{prefix}.subject",
                    "body": {
                        "notification": {
                            "sendEmail": {key: {"subject": templates.subjects[key]}}
                        }
                    },
                }
            )
        remote_body = remote.get("body") or ""
        if remote_body != templates.bodies[key]:
            patches.append(
                {
                    "update_mask": f"{prefix}.body,{prefix}.bodyFormat",
                    "body": {
                        "notification": {
                            "sendEmail": {
                                key: {
                                    "body": templates.bodies[key],
                                    "bodyFormat": "HTML",
                                }
                            }
                        }
                    },
                }
            )
    return patches


def patch_blocked(response_text: str) -> bool:
    return "EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED" in response_text


def dumps_patch(patch: dict[str, Any]) -> str:
    return json.dumps(patch["body"], ensure_ascii=False)


def main(argv: list[str] | None = None) -> int:
    import sys

    args = list(sys.argv[1:] if argv is None else argv)
    command = args[0] if args else ""
    if command == "local-check":
        errors = local_errors(load_templates())
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("Firebase auth email templates OK.")
        return 0
    if command == "brand-action":
        raw = args[1] if len(args) > 1 else "MISSING"
        title = None if raw == "MISSING" else raw
        print(brand_action(title))
        return 0
    if command == "plan-patches":
        config = json.loads(Path(args[1]).read_text(encoding="utf-8"))
        patches = plan_patches(config, load_templates())
        Path(args[2]).write_text(json.dumps(patches), encoding="utf-8")
        print(len(patches))
        return 0
    if command == "evaluate":
        payload = json.loads(Path(args[1]).read_text(encoding="utf-8"))
        errors = remote_errors(
            config=payload.get("config") or {},
            templates=load_templates(),
            brand_title=payload.get("brand_title"),
            gcp_project_name=payload.get("gcp_project_name"),
            firebase_display_name=payload.get("firebase_display_name"),
        )
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print(f"Firebase auth email branding matches {PUBLIC_NAME}.")
        return 0
    print(
        "Usage: firebase_auth_email_config.py "
        "{local-check|brand-action TITLE|plan-patches CONFIG.json OUT.json|evaluate SNAPSHOT.json}",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
