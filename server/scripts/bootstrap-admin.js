'use strict';
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { randomUUID } = require('node:crypto');
const { db, ensurePassword, now } = require('../src/core');

async function main() {
  const email = String(process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Set a valid ADMIN_EMAIL');
  ensurePassword(password);
  // This MUST run once on your machine, not in a Vercel build/start hook.
  await db.transaction(async () => {
    const count = (await db.prepare("SELECT COUNT(*) AS c FROM users WHERE account_type='superadmin' AND deleted_at IS NULL").get()).c;
    if (count) throw new Error('A superadmin already exists. Refusing to overwrite.');
    const date = now();
    await db.prepare(`INSERT INTO users(id,display_name,email,account_type,password_hash,is_active,created_at,updated_at)
   VALUES(?,?,?,?,?,1,?,?)`).run(
     randomUUID(),
     'Superadmin',
     email,
     'superadmin',
     bcrypt.hashSync(password, 12),
     date,
     date
   );
  });
  console.log('Superadmin created. Remove ADMIN_PASSWORD from your environment and command history.');
}
main().catch(e => { console.error('Bootstrap failed:', e.message); process.exitCode = 1; }).finally(() => db.close());
