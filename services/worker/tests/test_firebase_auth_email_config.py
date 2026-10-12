import json
import sys
from pathlib import Path

import pytest

_SCRIPTS = Path(__file__).resolve().parents[3] / "scripts"
sys.path.insert(0, str(_SCRIPTS))

from firebase_auth_email_config import (  # noqa: E402
    PUBLIC_NAME,
    body_branded,
    brand_action,
    load_templates,
    local_errors,
    plan_patches,
    remote_errors,
    subject_branded,
)
from render_invite_hosting import (  # noqa: E402
    render_apple_app_site_association,
    render_assetlinks,
)

_HOSTING = Path(__file__).resolve().parents[3] / "hosting"


def _config(subject: str, body: str, sender: str = "La Nonna") -> dict:
    template = {
        "senderDisplayName": sender,
        "subject": subject,
        "body": body,
        "bodyFormat": "HTML",
    }
    return {
        "notification": {
            "sendEmail": {
                "verifyEmailTemplate": template,
                "resetPasswordTemplate": dict(template),
            }
        }
    }


def test_local_templates_mention_la_nonna_and_link():
    templates = load_templates()
    assert local_errors(templates) == []
    assert "Verify my email" in templates.bodies["verifyEmailTemplate"]
    assert "Reset my password" in templates.bodies["resetPasswordTemplate"]


def test_brand_action_does_not_create_a_missing_brand():
    assert brand_action(None) == "console"
    assert brand_action("project-1008830071001") == "patch"
    assert brand_action(PUBLIC_NAME) == "ok"


def test_subject_accepts_custom_copy_or_app_name_placeholder():
    assert subject_branded(
        "Confirm your email for La Nonna",
        desired="Confirm your email for La Nonna",
        brand_title="project-1008830071001",
    )
    assert subject_branded(
        "Verify your email for %APP_NAME%",
        desired="Confirm your email for La Nonna",
        brand_title=PUBLIC_NAME,
    )
    assert not subject_branded(
        "Verify your email for %APP_NAME%",
        desired="Confirm your email for La Nonna",
        brand_title="project-1008830071001",
    )


def test_plan_patches_is_empty_when_remote_matches():
    templates = load_templates()
    config = {
        "notification": {
            "sendEmail": {
                "verifyEmailTemplate": {
                    "senderDisplayName": "La Nonna",
                    "subject": templates.subjects["verifyEmailTemplate"],
                    "body": templates.bodies["verifyEmailTemplate"],
                },
                "resetPasswordTemplate": {
                    "senderDisplayName": "La Nonna",
                    "subject": templates.subjects["resetPasswordTemplate"],
                    "body": templates.bodies["resetPasswordTemplate"],
                },
            }
        }
    }
    assert plan_patches(config, templates) == []


def test_plan_patches_includes_only_drifted_fields():
    templates = load_templates()
    config = _config(
        subject="Verify your email for %APP_NAME%",
        body="Hello",
        sender="Firebase",
    )
    masks = [patch["update_mask"] for patch in plan_patches(config, templates)]
    assert "notification.sendEmail.verifyEmailTemplate.senderDisplayName" in masks
    assert "notification.sendEmail.verifyEmailTemplate.subject" in masks
    assert "notification.sendEmail.verifyEmailTemplate.body,notification.sendEmail.verifyEmailTemplate.bodyFormat" in masks
    assert any(mask.startswith("notification.sendEmail.resetPasswordTemplate") for mask in masks)


def test_remote_errors_when_public_name_is_the_numeric_default():
    templates = load_templates()
    errors = remote_errors(
        config=_config(
            subject="Verify your email for %APP_NAME%",
            body=templates.bodies["verifyEmailTemplate"],
        ),
        templates=templates,
        brand_title="project-1008830071001",
        gcp_project_name=PUBLIC_NAME,
        firebase_display_name=PUBLIC_NAME,
    )
    assert any("%APP_NAME%" in error or "Public-facing name" in error for error in errors)
    assert any("resetPasswordTemplate body" in error for error in errors)


def test_remote_errors_pass_when_brand_and_templates_match():
    templates = load_templates()
    config = {
        "notification": {
            "sendEmail": {
                key: {
                    "senderDisplayName": "La Nonna",
                    "subject": templates.subjects[key],
                    "body": templates.bodies[key],
                }
                for key in templates.subjects
            }
        }
    }
    assert (
        remote_errors(
            config=config,
            templates=templates,
            brand_title=PUBLIC_NAME,
            gcp_project_name=PUBLIC_NAME,
            firebase_display_name=PUBLIC_NAME,
        )
        == []
    )


def test_body_marker_requires_link_and_product_name():
    assert body_branded(
        '<a href="%LINK%">Verify my email</a> La Nonna',
        marker="Verify my email",
    )
    assert not body_branded("Hello", marker="Verify my email")


def test_assetlinks_normalizes_fingerprints():
    digest = "ab" * 32
    rendered = render_assetlinks([digest])
    fingerprints = rendered[0]["target"]["sha256_cert_fingerprints"]
    assert fingerprints[0] == ":".join(digest[i : i + 2] for i in range(0, 64, 2)).upper()
    assert rendered[0]["target"]["package_name"] == "com.lanonna.lanonna"


def test_assetlinks_rejects_a_short_fingerprint():
    with pytest.raises(ValueError):
        render_assetlinks(["abcd"])


def test_aasa_includes_invite_and_auth_paths_when_team_is_set():
    rendered = render_apple_app_site_association("AB12CD34EF")
    detail = rendered["applinks"]["details"][0]
    assert detail["appID"] == "AB12CD34EF.com.lanonna.lanonna"
    assert "/invite" in detail["paths"]
    assert "/__/auth/action" in detail["paths"]


def test_aasa_without_team_id_does_not_claim_the_app():
    rendered = render_apple_app_site_association(None)
    assert rendered["applinks"]["details"] == []


def test_aasa_rejects_a_bad_team_id():
    with pytest.raises(ValueError):
        render_apple_app_site_association("not-a-team")


def test_invite_landing_page_does_not_log_and_offers_a_fallback():
    page = (_HOSTING / "public" / "invite" / "index.html").read_text(encoding="utf-8")
    assert "console." not in page
    assert "/v1/invitations/preview" in page
    assert "play.google.com/store/apps/details?id=com.lanonna.lanonna" in page
    assert "install it" in page.lower()
    assert "lanonna://app/invite-accept?token=" in page


def test_hosting_config_deploys_well_known_and_invite_page():
    config = json.loads((_HOSTING / "firebase.json").read_text(encoding="utf-8"))
    hosting = config["hosting"]
    # The default `**/.*` ignore drops `.well-known` (assetlinks and AASA).
    assert "**/.*" not in hosting["ignore"]
    sources = {item["source"]: item for item in hosting["rewrites"]}
    assert sources["/v1/invitations/preview"]["run"]["serviceId"] == "api"
    assert sources["/invite"]["destination"] == "/invite/index.html"
    assert sources["/invite/**"]["destination"] == "/invite/index.html"


def test_checked_in_aasa_is_valid_json_without_a_placeholder_team():
    for relative in (
        "public/.well-known/apple-app-site-association",
        "public/apple-app-site-association",
    ):
        payload = json.loads((_HOSTING / relative).read_text(encoding="utf-8"))
        assert payload["applinks"]["details"] == []
