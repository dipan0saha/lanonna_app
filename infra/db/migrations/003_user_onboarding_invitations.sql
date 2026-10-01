-- User profile + owner onboarding completion; baby lifecycle; invitations.

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS display_name TEXT,
    ADD COLUMN IF NOT EXISTS owner_onboarding_completed_at TIMESTAMPTZ;

ALTER TABLE baby_profiles
    ADD COLUMN IF NOT EXISTS lifecycle_status TEXT NOT NULL DEFAULT 'expecting'
        CHECK (lifecycle_status IN ('expecting', 'born'));

CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    inviter_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    invitee_email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'follower')),
    relationship_label TEXT,
    token_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_invitations_pending_email
    ON invitations (baby_profile_id, lower(invitee_email))
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_invitations_baby_status
    ON invitations (baby_profile_id, status);

INSERT INTO schema_migrations (version) VALUES ('003_user_onboarding_invitations')
ON CONFLICT (version) DO NOTHING;
