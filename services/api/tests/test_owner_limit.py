import pytest

from lanonna_api.domain.owner_limit import (
    MAX_OWNERS_PER_BABY,
    MaxOwnersError,
    ensure_owner_slot_for_accept,
    owner_slots_remaining,
)


def test_slots_count_active_owners_and_reserved_invites():
    assert MAX_OWNERS_PER_BABY == 2
    assert owner_slots_remaining(1) == 1
    assert owner_slots_remaining(1, 1) == 0
    assert owner_slots_remaining(2, 3) == 0


def test_accept_needs_a_free_active_slot():
    ensure_owner_slot_for_accept(1)
    with pytest.raises(MaxOwnersError) as exc:
        ensure_owner_slot_for_accept(2)
    assert exc.value.code == "max_owners"
    assert exc.value.params == {"max_owners": 2}
