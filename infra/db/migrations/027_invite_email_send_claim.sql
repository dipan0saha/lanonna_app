-- Invite email send claim before Mailjet (M-12).

ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS email_send_claimed_at TIMESTAMPTZ;

INSERT INTO schema_migrations (version) VALUES ('027_invite_email_send_claim')
ON CONFLICT (version) DO NOTHING;
