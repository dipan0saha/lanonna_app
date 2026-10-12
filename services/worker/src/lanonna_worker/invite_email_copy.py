"""Role-specific invite email copy.

Keep wording aligned with in-app invite landing (`InviteLandingHeader` /
`InviteReassureRow` in `invite_landing_widgets.dart`).
"""

from html import escape


def invite_email_subject(inviter: str, baby: str, role: str) -> str:
    if role == "owner":
        return f"{inviter} invited you to co-manage {baby} on La Nonna"
    return f"{inviter} invited you to {baby} on La Nonna"


def invite_email_intro_text(inviter: str, baby: str, role: str) -> str:
    if role == "owner":
        return (
            f"{inviter} invited you to join as a co-owner of {baby}'s profile. "
            "You'll be able to post updates, manage the registry and invite family."
        )
    return f"{inviter} invited you to follow {baby}'s journey on La Nonna."


def invite_email_intro_html(inviter: str, baby: str, role: str) -> str:
    inv = escape(inviter)
    bby = escape(baby)
    if role == "owner":
        return (
            f"<strong>{inv}</strong> invited you to join as a "
            f"<strong>co-owner</strong> of <strong>{bby}</strong>'s profile. "
            "You'll be able to post updates, manage the registry and invite family."
        )
    return (
        f"<strong>{inv}</strong> invited you to follow "
        f"<strong>{bby}</strong>'s journey on La Nonna."
    )
