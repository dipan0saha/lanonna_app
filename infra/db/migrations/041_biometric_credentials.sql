-- Device-bound biometric sign-in credentials (M-31 extension).

CREATE TABLE IF NOT EXISTS biometric_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    public_key_pem TEXT NOT NULL,
    algorithm TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS biometric_credentials_active_device_uid
    ON biometric_credentials (firebase_uid, device_id)
    WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS biometric_credentials_firebase_uid_idx
    ON biometric_credentials (firebase_uid)
    WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS biometric_sign_in_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credential_id UUID NOT NULL REFERENCES biometric_credentials (id) ON DELETE CASCADE,
    nonce TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS biometric_sign_in_challenges_expires_idx
    ON biometric_sign_in_challenges (expires_at)
    WHERE used_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('041_biometric_credentials')
ON CONFLICT (version) DO NOTHING;
