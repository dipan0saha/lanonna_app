-- Device-bound biometric sign-in (M-31 extension).
-- One hardware key per install signs a single-use server nonce; the API then
-- mints a Firebase custom token. Only the public key is stored.

CREATE TABLE IF NOT EXISTS biometric_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    public_key_pem TEXT NOT NULL,
    algorithm TEXT NOT NULL CHECK (algorithm IN ('ecdsa_p256_sha256')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

-- At most one live credential per account per install (re-enrolling replaces it).
CREATE UNIQUE INDEX IF NOT EXISTS biometric_credentials_active_uid_device
    ON biometric_credentials (firebase_uid, device_id)
    WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS biometric_sign_in_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credential_id UUID NOT NULL REFERENCES biometric_credentials (id) ON DELETE CASCADE,
    nonce TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS biometric_sign_in_challenges_credential_idx
    ON biometric_sign_in_challenges (credential_id);

INSERT INTO schema_migrations (version) VALUES ('041_biometric_credentials')
ON CONFLICT (version) DO NOTHING;
