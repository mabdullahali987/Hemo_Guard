'use strict';
// One-time, atomic migration of an EXISTING SQLite installation into an EMPTY
// HemoGuard PostgreSQL schema. Never run this from a serverless request.
require('dotenv').config();
const path = require('node:path');
const fs = require('node:fs');
const Database = require('better-sqlite3'); // development-only dependency
const db = require('../src/db');
const tables = [
  'users', 'sessions', 'reports', 'audit_events', 'patients',
  'consent_intents', 'patient_consents', 'clinical_reports',
];
async function main() {
  const filename = process.env.SQLITE_IMPORT_PATH;
  if (!filename || !fs.existsSync(filename)) throw new Error('Set SQLITE_IMPORT_PATH to your existing SQLite file');
  if (!process.env.DATABASE_URL) throw new Error('Set DATABASE_URL to Supabase Postgres');
  if (process.env.NODE_ENV === 'test') throw new Error('Do not use test mode for a production migration');
  const source = new Database(path.resolve(filename), { readonly: true, fileMustExist: true });
  try {
    const present = new Set(source.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(x => x.name));
    await db.transaction(async () => {
      // Never mix two accounts' existing data, or accidentally overwrite an admin.
      for (const name of tables) {
        const current = (await db.prepare(`SELECT COUNT(*) AS c FROM ${name}`).get()).c;
        if (current) throw new Error('Destination HemoGuard schema is not empty; import aborted');
      }
      for (const name of tables) {
        if (!present.has(name)) continue; // older installs lack clinical tables
        const rows = source.prepare(`SELECT * FROM ${name}`).all();
        const columns = (await db.prepare(`SELECT column_name FROM information_schema.columns WHERE table_schema='hemoguard' AND table_name=?`).all(name))
          .map(row => row.column_name);
        const writable = new Set(columns);
        for (const record of rows) {
          const keys = Object.keys(record).filter(key => writable.has(key));
          if (!keys.length) throw new Error('No compatible columns for table ' + name);
          const marks = keys.map(() => '?').join(',');
          await db.prepare(`INSERT INTO ${name} (${keys.join(',')}) VALUES (${marks})`).run(...keys.map(key => record[key]));
        }
        const after = (await db.prepare(`SELECT COUNT(*) AS c FROM ${name}`).get()).c;
        if (after !== rows.length) throw new Error('Import row count mismatch for table ' + name);
        console.log(`Verified ${name}: ${after} rows`);
      }
    });
    console.log('SQLite to PostgreSQL import committed. Keep the original SQLite backup safe.');
  } finally { source.close(); }
}
main().catch(error => { console.error('Import stopped and rolled back:', error.message); process.exitCode = 1; })
  .finally(() => db.close());
