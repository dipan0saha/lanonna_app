from lanonna_api.text_ilike import escape_ilike_literal, ilike_substring_pattern


def test_escape_ilike_literal_escapes_wildcards_and_backslash():
    assert escape_ilike_literal(r"a%b_c\d") == r"a\%b\_c\\d"


def test_ilike_substring_pattern_wraps_escaped_literal():
    assert ilike_substring_pattern("100%") == r"%100\%%"
