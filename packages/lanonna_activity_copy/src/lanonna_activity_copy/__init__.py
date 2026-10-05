"""Shared activity event copy for API and worker."""

EVENT_PHOTO_SHARED = "photo_shared"
EVENT_PHOTO_SQUISH = "photo_squish"
EVENT_PHOTO_COMMENT = "photo_comment"

GALLERY_ACTIVITY_EVENT_TYPES: frozenset[str] = frozenset(
    {EVENT_PHOTO_SQUISH, EVENT_PHOTO_COMMENT}
)


def _truncate_caption(caption: str | None, max_len: int = 60) -> str:
    text = (caption or "").strip()
    if not text:
        return "a photo"
    if len(text) <= max_len:
        return text
    return f"{text[: max_len - 1].rstrip()}…"


def photo_shared_summary(actor: str, caption: str | None) -> str:
    label = _truncate_caption(caption)
    if caption and caption.strip():
        return f'{actor} added "{label}"'
    return f"{actor} shared a photo"


def photo_squish_summary(actor: str, caption: str | None) -> str:
    label = _truncate_caption(caption)
    return f'{actor} squished "{label}"'


def photo_comment_summary(actor: str, caption: str | None) -> str:
    label = _truncate_caption(caption)
    return f'{actor} commented on "{label}"'
