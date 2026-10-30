-- Run once in Supabase SQL Editor, AFTER 001_schema.sql.
-- Historical reports remain valid; new reports require an explicit carrier answer in the API.
BEGIN;
ALTER TABLE hemoguard.clinical_reports ADD COLUMN IF NOT EXISTS hematologist_carrier TEXT
  CHECK(hematologist_carrier IN ('yes','no') OR hematologist_carrier IS NULL);
ALTER TABLE hemoguard.clinical_reports ADD COLUMN IF NOT EXISTS hematologist_name TEXT;
ALTER TABLE hemoguard.clinical_reports ADD COLUMN IF NOT EXISTS hematologist_notes TEXT;
CREATE TABLE IF NOT EXISTS hemoguard.clinical_attachments (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES hemoguard.users(id),
  consent_intent_id TEXT NOT NULL REFERENCES hemoguard.consent_intents(id),
  report_id TEXT REFERENCES hemoguard.clinical_reports(id),
  kind TEXT NOT NULL CHECK(kind IN ('consent_document','electrophoresis')),
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  byte_length INTEGER NOT NULL CHECK(byte_length > 0 AND byte_length <= 1200000),
  data BYTEA NOT NULL,
  uploaded_at TEXT NOT NULL,
  UNIQUE(consent_intent_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_clinical_attachments_report ON hemoguard.clinical_attachments(report_id);
CREATE INDEX IF NOT EXISTS idx_clinical_attachments_intent ON hemoguard.clinical_attachments(consent_intent_id);
REVOKE ALL ON hemoguard.clinical_attachments FROM PUBLIC;
COMMIT;
