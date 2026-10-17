"""How many owners a baby profile may have, in one place.

A baby has at most :data:`MAX_OWNERS_PER_BABY` owners (the creator plus one
co-owner). Two write paths depend on it:

- **Batch invite** (``POST /v1/babies/{id}/invitations/batch``): every pending,
  unexpired owner invite reserves a slot, so an owner cannot hand out more
  co-owner invites than can ever be accepted. Rows over the limit come back as
  ``skipped_max_owners``.
- **Invite accept** (``POST /v1/invitations/accept``): only active owners count
  (the invite being accepted holds one of the reserved slots); a full baby
  raises :class:`MaxOwnersError` (409 ``max_owners``).

Both callers hold the baby row lock (``lock_baby_profile_for_update``) while
they count, so concurrent requests cannot overshoot.
"""

from __future__ import annotations

from lanonna_api.domain.errors import ConflictError, ErrorCode

MAX_OWNERS_PER_BABY = 2


class MaxOwnersError(ConflictError):
    def __init__(self) -> None:
        super().__init__(
            ErrorCode.MAX_OWNERS,
            f"A baby profile can have at most {MAX_OWNERS_PER_BABY} owners.",
            params={"max_owners": MAX_OWNERS_PER_BABY},
        )


def owner_slots_remaining(active_owners: int, reserved_owner_invites: int = 0) -> int:
    """Owner slots still free after active owners and reserved (pending) invites."""
    return max(0, MAX_OWNERS_PER_BABY - active_owners - reserved_owner_invites)


def ensure_owner_slot_for_accept(active_owners: int) -> None:
    """Accepting an owner invite needs a free slot among active owners."""
    if owner_slots_remaining(active_owners) == 0:
        raise MaxOwnersError()
