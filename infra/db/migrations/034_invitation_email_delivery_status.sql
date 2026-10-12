-- Track invite email delivery outcomes (#62). Rows stay pending until accept/revoke;
-- owners can resend when delivery failed or never completed.

ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS email_delivery_status TEXT;

ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS email_last_error TEXT;

ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS email_send_attempts INTEGER NOT NULL DEFAULT 0;

UPDATE invitations
SET email_delivery_status = 'sent'
WHERE email_delivery_status IS NULL
  AND email_sent_at IS NOT NULL;

UPDATE invitations
SET email_delivery_status = 'pending'
WHERE email_delivery_status IS NULL;

ALTER TABLE invitations
    ALTER COLUMN email_delivery_status SET DEFAULT 'pending';

ALTER TABLE invitations
    ALTER COLUMN email_delivery_status SET NOT NULL;

ALTER TABLE invitations
    DROP CONSTRAINT IF EXISTS invitations_email_delivery_status_check;

ALTER TABLE invitations
    ADD CONSTRAINT invitations_email_delivery_status_check
    CHECK (email_delivery_status IN ('pending', 'sent', 'failed'));

INSERT INTO schema_migrations (version) VALUES ('034_invitation_email_delivery_status')
ON CONFLICT (version) DO NOTHING;
