-- HemoGuard PostgreSQL schema. Run ONCE in the Supabase SQL Editor before
-- deploying Vercel. Text ISO8601 timestamps and integer flags are deliberate:
-- they keep the Flutter API's serialized types and access rules unchanged.
-- 'hemoguard' is a private schema, not served by the default Supabase Data API.
BEGIN;
CREATE SCHEMA IF NOT EXISTS hemoguard;
SET LOCAL search_path TO hemoguard, public;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  account_type TEXT NOT NULL CHECK(account_type IN ('person','lab','superadmin')),
  password_hash TEXT NOT NULL,
  access_plan TEXT CHECK(access_plan IN ('trial','subscription') OR access_plan IS NULL),
  plan_started_at TEXT, plan_expires_at TEXT, plan_stopped_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
  can_view_results INTEGER NOT NULL DEFAULT 0 CHECK(can_view_results IN (0,1)),
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT,
  profile_image_data TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_live_email ON users (lower(email)) WHERE deleted_at IS NULL;
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
  token_hash TEXT NOT NULL UNIQUE, csrf_token TEXT NOT NULL,
  created_at TEXT NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE TABLE IF NOT EXISTS reports (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
  mode TEXT NOT NULL CHECK(mode IN ('image','text')),
  created_at TEXT NOT NULL, expires_at TEXT NOT NULL, completed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_reports_user_done ON reports(user_id,completed_at);
CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY, actor_id TEXT REFERENCES users(id), subject_id TEXT REFERENCES users(id),
  action TEXT NOT NULL, details_json TEXT NOT NULL DEFAULT '{}', created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_events(created_at DESC);
CREATE TABLE IF NOT EXISTS patients (
  id TEXT PRIMARY KEY, public_id TEXT NOT NULL UNIQUE,
  account_id TEXT NOT NULL REFERENCES users(id), name TEXT NOT NULL,
  name_key TEXT NOT NULL, age_at_registration INTEGER,
  sex TEXT NOT NULL DEFAULT 'unknown' CHECK(sex IN ('male','female','other','unknown')),
  lab_patient_number TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_patient_account_name ON patients(account_id,name_key);
CREATE UNIQUE INDEX IF NOT EXISTS idx_patient_lab_number ON patients(account_id,lab_patient_number)
  WHERE lab_patient_number IS NOT NULL;
CREATE TABLE IF NOT EXISTS consent_intents (
  id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES users(id), consent_version TEXT NOT NULL,
  method TEXT NOT NULL CHECK(method='operator_checkbox'),
  accepted_at TEXT NOT NULL, expires_at TEXT NOT NULL, consumed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_consent_account ON consent_intents(account_id);
CREATE TABLE IF NOT EXISTS patient_consents (
  id TEXT PRIMARY KEY, intent_id TEXT NOT NULL UNIQUE REFERENCES consent_intents(id),
  patient_id TEXT NOT NULL REFERENCES patients(id), account_id TEXT NOT NULL REFERENCES users(id),
  consent_version TEXT NOT NULL, method TEXT NOT NULL, recorded_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS clinical_reports (
  id TEXT PRIMARY KEY, authorization_id TEXT NOT NULL UNIQUE REFERENCES reports(id),
  client_request_id TEXT, patient_id TEXT NOT NULL REFERENCES patients(id),
  account_id TEXT NOT NULL REFERENCES users(id),
  account_name_snapshot TEXT NOT NULL, account_type_snapshot TEXT NOT NULL,
  patient_name_snapshot TEXT NOT NULL, patient_age_at_test INTEGER,
  patient_sex_at_test TEXT NOT NULL, source_report_number TEXT,
  sample_date TEXT, cbc_json TEXT NOT NULL, prediction_json TEXT NOT NULL,
  consent_id TEXT NOT NULL UNIQUE REFERENCES patient_consents(id), created_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_clinical_client_request ON clinical_reports(account_id,client_request_id)
  WHERE client_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_clinical_patient_time ON clinical_reports(patient_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clinical_account_time ON clinical_reports(account_id,created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_clinical_source_duplicate ON clinical_reports(account_id,patient_id,source_report_number)
  WHERE source_report_number IS NOT NULL;
-- Do not grant anon / authenticated / PUBLIC data access.
REVOKE ALL ON SCHEMA hemoguard FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA hemoguard FROM PUBLIC;
COMMIT;
