"""SQL filter that keeps birthdate votes inside a ``BirthdateVoteWindow`` (#413).

The fragment expects the votes table aliased ``v`` and named parameters.
"""

from __future__ import annotations

from typing import Any

from lanonna_api.domain.birthdate_vote_window import BirthdateVoteWindow

BIRTHDATE_WINDOW_SQL = """
    AND (%(vote_earliest)s::date IS NULL
         OR v.predicted_birth_date >= %(vote_earliest)s::date)
    AND (%(vote_latest)s::date IS NULL
         OR v.predicted_birth_date <= %(vote_latest)s::date)
"""


def birthdate_window_params(window: BirthdateVoteWindow) -> dict[str, Any]:
    return {"vote_earliest": window.earliest, "vote_latest": window.latest}
