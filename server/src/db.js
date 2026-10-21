'use strict';
const fs = require('node:fs');
const path = require('node:path');
const Database = require('better-sqlite3');

const file = path.resolve(process.env.DATABASE_PATH || path.join(__dirname, '..', 'data', 'hemo-guard.sqlite'));
fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
const db = new Database(file);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.pragma('busy_timeout = 5000');
db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  account_type TEXT NOT NULL CHECK(account_type IN ('person','lab','superadmin')),
  password_hash TEXT NOT NULL,
  access_plan TEXT CHECK(access_plan IN ('trial','subscription') OR access_plan IS NULL),
  plan_started_at TEXT,
  plan_expires_at TEXT,
  plan_stopped_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  profile_image_data TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_live_email ON users(email COLLATE NOCASE) WHERE deleted_at IS NULL;
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  token_hash TEXT NOT NULL UNIQUE,
  csrf_token TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE TABLE IF NOT EXISTS reports (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  mode TEXT NOT NULL CHECK(mode IN ('image','text')),
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  completed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_reports_user_done ON reports(user_id,completed_at);
CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  actor_id TEXT REFERENCES users(id),
  subject_id TEXT REFERENCES users(id),
  action TEXT NOT NULL,
  details_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_events(created_at DESC);
`);

// Forward-compatible migration for installations created before admin profile pictures existed.
// SQLite does not support IF NOT EXISTS for ADD COLUMN on all deployed versions, so inspect first.
const userColumns = new Set(db.prepare('PRAGMA table_info(users)').all().map(row => row.name));
if (!userColumns.has('profile_image_data')) {
  db.exec('ALTER TABLE users ADD COLUMN profile_image_data TEXT');
}
module.exports = db;
