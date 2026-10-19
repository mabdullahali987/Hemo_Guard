'use strict';
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { randomUUID } = require('node:crypto');
const { db, ensurePassword, now } = require('../src/core');
const email = String(process.env.ADMIN_EMAIL || '').trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD;
if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Set a valid ADMIN_EMAIL in environment');
ensurePassword(password);
const existing = db.prepare("SELECT COUNT(*) AS c FROM users WHERE account_type='superadmin' AND deleted_at IS NULL").get().c;
if (existing) throw new Error('A superadmin already exists. This command will not overwrite any admin.');
const date = now();
db.prepare(`INSERT INTO users(id,display_name,email,account_type,password_hash,is_active,created_at,updated_at)
 VALUES(?,?,?,?,?,1,?,?)`).run(randomUUID(),'Superadmin',email,'superadmin',bcrypt.hashSync(password,12),date,date);
console.log(`Superadmin created: ${email}. Remove ADMIN_PASSWORD from environment now.`);
