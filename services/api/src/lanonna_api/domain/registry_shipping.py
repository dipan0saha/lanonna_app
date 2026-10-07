from __future__ import annotations

from typing import Any


def _country_name(country_code: str | None) -> str | None:
    if not country_code:
        return None
    try:
        import pycountry

        country = pycountry.countries.get(alpha_2=country_code.upper())
        if country is not None:
            return country.name
    except Exception:
        pass
    return country_code.upper()


def shipping_fields_from_row(row: dict[str, Any] | None) -> dict[str, str | None]:
    if row is None:
        return {
            "line1": None,
            "line2": None,
            "city": None,
            "region": None,
            "postal_code": None,
            "country_code": None,
        }
    return {
        "line1": row.get("registry_shipping_line1"),
        "line2": row.get("registry_shipping_line2"),
        "city": row.get("registry_shipping_city"),
        "region": row.get("registry_shipping_region"),
        "postal_code": row.get("registry_shipping_postal_code"),
        "country_code": row.get("registry_shipping_country_code"),
    }


def shipping_is_empty(fields: dict[str, str | None]) -> bool:
    return not any(fields.get(k) for k in fields)


def format_shipping_address(fields: dict[str, str | None]) -> str | None:
    if shipping_is_empty(fields):
        return None
    lines: list[str] = []
    if fields.get("line1"):
        lines.append(fields["line1"])
    if fields.get("line2"):
        lines.append(fields["line2"])
    city_parts: list[str] = []
    if fields.get("city"):
        city_parts.append(fields["city"])
    region_postal = " ".join(
        p
        for p in (fields.get("region"), fields.get("postal_code"))
        if p
    )
    if region_postal:
        if city_parts:
            city_parts[0] = f"{city_parts[0]}, {region_postal}"
        else:
            city_parts.append(region_postal)
    if city_parts:
        lines.append(city_parts[0])
    country = _country_name(fields.get("country_code"))
    if country:
        lines.append(country)
    return "\n".join(lines) if lines else None


def shipping_response_from_row(row: dict[str, Any] | None) -> dict[str, Any]:
    fields = shipping_fields_from_row(row)
    formatted = format_shipping_address(fields)
    return {**fields, "formatted": formatted}


def validate_shipping_patch(fields: dict[str, str | None]) -> None:
    """Raise ValueError when patch is partial (some but not all required fields)."""
    if shipping_is_empty(fields):
        return
    required = ("line1", "city", "postal_code", "country_code")
    missing = [k for k in required if not fields.get(k)]
    if missing:
        raise ValueError(
            "Shipping address requires line1, city, postal_code, and country_code."
        )
