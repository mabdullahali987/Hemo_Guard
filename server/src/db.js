'use strict';
// PostgreSQL adapter. The public API of prepared statements is intentionally
// preserved while database operations become asynchronous. Never use this
// module from Flutter: only the trusted server holds DATABASE_URL.
const { AsyncLocalStorage } = require('node:async_hooks');
const txContext = new AsyncLocalStorage();
let pool;

// Existing test suite uses an isolated SQLite fixture to check that all API,
// consent, authorization and admin flows retain the same external behavior.
// Production never loads the SQLite driver.
const sqliteTest = process.env.NODE_ENV === 'test' && Boolean(process.env.DATABASE_PATH);
if (sqliteTest) {
  const sqlite = require('../test/support/sqlite-original');
  let transactionDepth = 0;
  module.exports = {
    prepare(statement) {
      // Test-only approximation of PostgreSQL SQL constructs for legacy tests.
      let query = statement.replace(/\bILIKE\b/gi, 'LIKE')
        .replace(/\s+FOR UPDATE\b/gi, '')
        .replace(/\bLOWER\(email\)\s*=\s*LOWER\(\?\)/gi, 'email = ? COLLATE NOCASE');
      return {
        async get(...args) { return sqlite.prepare(query).get(...args); },
        async all(...args) { return sqlite.prepare(query).all(...args); },
        async run(...args) { return sqlite.prepare(query).run(...args); },
      };
    },
    async transaction(work) {
      // Not a production transaction implementation: test calls are sequential.
      const nesting = transactionDepth++;
      if (!nesting) sqlite.exec('BEGIN IMMEDIATE');
      try {
        const result = await work();
        if (!nesting) sqlite.exec('COMMIT');
        return result;
      } catch (error) {
        if (!nesting) sqlite.exec('ROLLBACK');
        throw error;
      } finally { transactionDepth--; }
    },
    async close() { sqlite.close(); },
  };
} else {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required (Supabase Postgres transaction pooler)');
  const { Pool, types } = require('pg');
  // Counts and integer SQL aggregates need to preserve the original API's
  // numeric JSON types. These counters are far below JS's safe integer limit.
  types.setTypeParser(20, value => Number(value));
  // Supabase's managed root CA is supplied as base64 in Vercel's environment.
  // The certificate is public trust material, not a database credential.
  // Keep certificate and hostname verification enabled.
  const caBase64 = process.env.DATABASE_CA_CERT_BASE64;
  const ca = caBase64 ? Buffer.from(caBase64, 'base64').toString('utf8') : undefined;
  if (caBase64 && (!ca.includes('-----BEGIN CERTIFICATE-----') || !ca.includes('-----END CERTIFICATE-----'))) {
    throw new Error('Invalid DATABASE_CA_CERT_BASE64: expected a base64-encoded PEM CA certificate');
  }
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: 1, // each warm Vercel function instance owns at most one connection
    connectionTimeoutMillis: 10000,
    idleTimeoutMillis: 10000,
    // Require TLS and verify hostname/certificate by default.
    // Local Postgres development may explicitly set DATABASE_SSL=disable.
    ssl: process.env.DATABASE_SSL === 'disable'
      ? false
      : { rejectUnauthorized: true, ...(ca ? { ca } : {}) },
  });
  pool.on('error', err => console.error('Idle database connection error:', err));
  function placeholders(statement) {
    let index = 0;
    // All existing HemoGuard queries use '?' only for parameters; none contain
    // question-mark JSON operators or literals. Keep bindings parameterized.
    // Supabase's private schema is explicitly qualified in every statement.
    const qualified = statement.replace(/\b(FROM|JOIN|INTO|UPDATE)\s+(users|sessions|reports|patients|clinical_reports|consent_intents|patient_consents|audit_events)\b/gi,
      (_, command, table) => `${command} hemoguard.${table}`);
    return qualified.replace(/\?/g, () => `$${++index}`);
  }
  async function query(statement, params) {
    const conn = txContext.getStore() || pool;
    return conn.query(placeholders(statement), params);
  }
  module.exports = {
    prepare(statement) {
      return {
        async get(...params) { return (await query(statement, params)).rows[0]; },
        async all(...params) { return (await query(statement, params)).rows; },
        async run(...params) { const response = await query(statement, params); return { changes: response.rowCount }; },
      };
    },
    async transaction(work) {
      if (txContext.getStore()) return work();
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const result = await txContext.run(client, work);
        await client.query('COMMIT');
        return result;
      } catch (err) {
        try { await client.query('ROLLBACK'); } catch (rollback) { console.error('Database rollback failed:', rollback); }
        throw err;
      } finally { client.release(); }
    },
    async close() { await pool.end(); },
  };
}
