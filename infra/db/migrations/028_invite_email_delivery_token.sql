-- Short-lived invite accept token for email delivery only (M-41). Cleared when email_sent_at is set.

ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS email_invite_token TEXT;

COMMENT ON COLUMN invitations.email_invite_token IS
    'Plaintext accept token for outbound email only; cleared after send. Accept auth uses token_hash.';

INSERT INTO schema_migrations (version) VALUES ('028_invite_email_delivery_token')
ON CONFLICT (version) DO NOTHING;
