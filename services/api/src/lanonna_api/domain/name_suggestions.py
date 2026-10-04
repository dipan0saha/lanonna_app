from __future__ import annotations

GENDERS_FUN_SUGGEST = frozenset({"male", "female"})
GENDERS_FIRST_MOMENT_SEED = frozenset({"male", "female", "unknown"})


def normalize_suggested_name(name: str) -> str:
    return (name or "").strip()


def normalize_gender_for_fun(gender: str) -> str:
    if gender not in GENDERS_FUN_SUGGEST:
        raise ValueError("Gender must be male or female.")
    return gender


def normalize_gender_for_first_moment_seed(gender: str) -> str:
    if gender in GENDERS_FIRST_MOMENT_SEED:
        return gender
    return "unknown"
