"""Role-specific invite email copy.

Keep wording aligned with in-app invite landing (`InviteLandingHeader` /
`InviteReassureRow` in `invite_landing_widgets.dart`).

``baby`` is the stored baby name, ``None`` while the owner has not named the
baby (``baby_profiles.name`` is never a placeholder). Unnamed babies read as
"their baby", the email counterpart of the app's localized fallback.
"""

from html import escape

UNNAMED_BABY = "their baby"


def _baby_text(baby: str | None) -> str:
    return (baby or "").strip() or UNNAMED_BABY


def _baby_html(baby: str | None) -> str:
    name = (baby or "").strip()
    return f"<strong>{escape(name)}</strong>" if name else UNNAMED_BABY


def invite_email_subject(inviter: str, baby: str | None, role: str) -> str:
    bby = _baby_text(baby)
    if role == "owner":
        return f"{inviter} invited you to co-manage {bby} on La Nonna"
    return f"{inviter} invited you to {bby} on La Nonna"


def invite_email_intro_text(inviter: str, baby: str | None, role: str) -> str:
    bby = _baby_text(baby)
    if role == "owner":
        return (
            f"{inviter} invited you to join as a co-owner of {bby}'s profile. "
            "You'll be able to post updates, manage the registry and invite family."
        )
    return f"{inviter} invited you to follow {bby}'s journey on La Nonna."


def invite_email_intro_html(inviter: str, baby: str | None, role: str) -> str:
    inv = escape(inviter)
    bby = _baby_html(baby)
    if role == "owner":
        return (
            f"<strong>{inv}</strong> invited you to join as a "
            f"<strong>co-owner</strong> of {bby}'s profile. "
            "You'll be able to post updates, manage the registry and invite family."
        )
    return (
        f"<strong>{inv}</strong> invited you to follow "
        f"{bby}'s journey on La Nonna."
    )
