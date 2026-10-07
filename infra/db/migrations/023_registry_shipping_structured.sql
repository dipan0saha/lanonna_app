-- Structured registry shipping address on baby_profiles (#408).

ALTER TABLE baby_profiles
    DROP COLUMN IF EXISTS registry_shipping_address;

ALTER TABLE baby_profiles
    ADD COLUMN IF NOT EXISTS registry_shipping_line1 TEXT,
    ADD COLUMN IF NOT EXISTS registry_shipping_line2 TEXT,
    ADD COLUMN IF NOT EXISTS registry_shipping_city TEXT,
    ADD COLUMN IF NOT EXISTS registry_shipping_region TEXT,
    ADD COLUMN IF NOT EXISTS registry_shipping_postal_code TEXT,
    ADD COLUMN IF NOT EXISTS registry_shipping_country_code CHAR(2);
