'use strict';
const { randomUUID, randomBytes, createHash } = require('node:crypto');
const bcrypt = require('bcryptjs');
const db = require('./db');
const { addDuration, accessState } = require('./time');

const now = () => new Date().toISOString();
const hash = (token) => createHash('sha256').update(token).digest('hex');
const fail = (message, status = 400) => { const e = new Error(message); e.status = status; throw e; };
const userById = (id) => db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(id);
const publicUser = (user) => {
  if (!user) return null;
  const { password_hash, ...rest } = user;
  const status = accessState(user);
  const expiry = user.plan_expires_at ? Date.parse(user.plan_expires_at) : NaN;
  // Round upward: '1 day remaining' includes the final 24 hours.
  // Return zero for stopped, expired, disabled and unassigned accounts.
  const daysRemaining = status === 'active' && user.account_type !== 'superadmin' &&
      Number.isFinite(expiry) ? Math.max(0, Math.ceil((expiry - Date.now()) / 86400000)) : 0;
  return { ...rest, status, is_active: Boolean(user.is_active), days_remaining: daysRemaining };
};
const ensureEmail = (email) => {
  const value = String(email || '').trim().toLowerCase();
  if (value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) fail('Enter a valid email');
  return value;
};
const ensureName = (value) => {
  const result = String(value || '').trim();
  if (result.length < 2 || result.length > 120) fail('Name must be 2–120 characters');
  return result;
};
const ensurePassword = (value) => {
  if (typeof value !== 'string' || value.length < 12 || Buffer.byteLength(value, 'utf8') > 72) fail('Password must be 12 characters or more, up to 72 UTF-8 bytes');
  return value;
};
const ensureType = (value) => {
  if (!['person', 'lab'].includes(value)) fail('Account type must be person or lab');
  return value;
};
function audit(actorId, subjectId, action, details = {}) {
  db.prepare('INSERT INTO audit_events (id,actor_id,subject_id,action,details_json,created_at) VALUES (?,?,?,?,?,?)')
    .run(randomUUID(), actorId, subjectId, action, JSON.stringify(details), now());
}
function planFromInput(type, value, unit, start = now()) {
  if (!['trial','subscription'].includes(type)) fail('Choose a trial or subscription');
  const number = Number(value);
  if (!Number.isInteger(number)) fail('Enter a whole-number duration');
  if (type === 'trial' && unit !== 'days') fail('Trials are measured in days');
  let expiry;
  try { expiry = addDuration(start, number, unit); } catch (e) { fail(e.message); }
  return { access_plan: type, plan_started_at: start, plan_expires_at: expiry, plan_stopped_at: null };
}
function createUser(input, actorId) {
  const id = randomUUID();
  const created = now();
  const name = ensureName(input.display_name);
  const email = ensureEmail(input.email);
  const type = ensureType(input.account_type);
  const passwordHash = bcrypt.hashSync(ensurePassword(input.password), 12);
  const plan = planFromInput(input.access_plan, input.duration, input.unit, created);
  try {
    db.transaction(() => {
      db.prepare(`INSERT INTO users (id,display_name,email,account_type,password_hash,access_plan,plan_started_at,plan_expires_at,plan_stopped_at,is_active,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,1,?,?)`).run(id, name, email, type, passwordHash,
          plan.access_plan, plan.plan_started_at, plan.plan_expires_at, null, created, created);
      audit(actorId, id, 'user.created', { account_type: type, access_plan: plan.access_plan, plan_expires_at: plan.plan_expires_at });
    })();
  } catch (e) { if (e.code?.startsWith('SQLITE_CONSTRAINT')) fail('That email is already registered', 409); throw e; }
  return publicUser(userById(id));
}
function editUser(id, input, actorId) {
  const user = userById(id);
  if (!user || user.account_type === 'superadmin') fail('User not found', 404);
  const name = ensureName(input.display_name);
  const email = ensureEmail(input.email);
  const type = ensureType(input.account_type);
  const active = input.is_active === true || input.is_active === 'true' || input.is_active === 'on' || input.is_active === '1';
  const passwordChanged = Boolean(input.password);
  const passwordHash = passwordChanged ? bcrypt.hashSync(ensurePassword(input.password), 12) : user.password_hash;
  try {
    db.transaction(() => {
      db.prepare('UPDATE users SET display_name=?,email=?,account_type=?,is_active=?,password_hash=?,updated_at=? WHERE id=?')
        .run(name, email, type, active ? 1 : 0, passwordHash, now(), id);
      if (passwordChanged || !active) revokeUserSessions(id);
      audit(actorId, id, 'user.updated', { account_type: type, is_active: active, password_reset: passwordChanged });
    })();
  } catch (e) { if (e.code?.startsWith('SQLITE_CONSTRAINT')) fail('That email is already registered', 409); throw e; }
  return publicUser(userById(id));
}
function revokeUserSessions(id) {
  db.prepare('UPDATE sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(now(), id);
}
function deleteUser(id, actorId) {
  const user = userById(id);
  if (!user || user.account_type === 'superadmin') fail('User not found', 404);
  db.transaction(() => {
    const when = now();
    db.prepare('UPDATE users SET deleted_at=?,is_active=0,updated_at=? WHERE id=?').run(when, when, id);
    revokeUserSessions(id);
    audit(actorId, id, 'user.deleted', { email: user.email });
  })();
}
function changePlan(id, input, actorId) {
  const user = userById(id);
  if (!user || user.account_type === 'superadmin') fail('User not found', 404);
  const action = String(input.action || '');
  const updates = {};
  const when = now();
  if (action === 'set_trial' || action === 'set_subscription') {
    Object.assign(updates, planFromInput(action === 'set_trial' ? 'trial' : 'subscription', input.duration,
      action === 'set_trial' ? 'days' : input.unit, when));
  } else if (action === 'extend_trial' || action === 'extend_subscription') {
    const expected = action === 'extend_trial' ? 'trial' : 'subscription';
    if (user.access_plan !== expected) fail(`User is not on a ${expected}`);
    if (user.plan_stopped_at) fail('Stopped plans must be restarted using Set plan');
    const baseline = user.plan_expires_at && user.plan_expires_at > when ? user.plan_expires_at : when;
    const unit = expected === 'trial' ? 'days' : input.unit;
    Object.assign(updates, { plan_started_at: user.plan_started_at || when, plan_expires_at: planFromInput(expected, input.duration, unit, baseline).plan_expires_at });
  } else if (action === 'stop_trial' || action === 'stop_subscription') {
    if (user.access_plan !== (action === 'stop_trial' ? 'trial' : 'subscription')) fail('Plan type mismatch');
    updates.plan_stopped_at = when;
  } else fail('Invalid plan action');
  db.transaction(() => {
    const values = Object.entries(updates);
    db.prepare(`UPDATE users SET ${values.map(([k]) => `${k}=?`).join(',')},updated_at=? WHERE id=?`)
      .run(...values.map(([, v]) => v), when, id);
    audit(actorId, id, `plan.${action}`, { plan_expires_at: updates.plan_expires_at || user.plan_expires_at });
  })();
  return publicUser(userById(id));
}
function createSession(user) {
  const token = randomBytes(32).toString('base64url');
  const expires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  db.prepare('INSERT INTO sessions (id,user_id,token_hash,csrf_token,created_at,expires_at) VALUES (?,?,?,?,?,?)')
    .run(randomUUID(), user.id, hash(token), randomBytes(32).toString('hex'), now(), expires);
  return token;
}
function findSession(token) {
  if (typeof token !== 'string' || token.length < 32 || token.length > 256) return null;
  const session = db.prepare(`SELECT s.*,u.id AS uid,u.email,u.display_name,u.account_type,u.access_plan,u.plan_started_at,u.plan_expires_at,u.plan_stopped_at,u.is_active,u.deleted_at,u.created_at AS user_created_at,u.updated_at AS user_updated_at
    FROM sessions s JOIN users u ON u.id=s.user_id
    WHERE s.token_hash=? AND s.revoked_at IS NULL AND s.expires_at>? AND u.deleted_at IS NULL AND u.is_active=1`).get(hash(token), now());
  if (!session) return null;
  const user = userById(session.user_id);
  return { session, user };
}
function revokeSession(token) { if (token) db.prepare('UPDATE sessions SET revoked_at=? WHERE token_hash=?').run(now(), hash(token)); }
function login(email, password) {
  const normalized = String(email || '').trim().toLowerCase();
  const user = db.prepare('SELECT * FROM users WHERE email=? COLLATE NOCASE AND deleted_at IS NULL AND is_active=1').get(normalized);
  // Always exercise bcrypt to reduce username existence signal.
  const dummy = '$2a$12$9dCSN0ZAuI3fKQG7zHO0iueV2sTaRxuOCdaPnvUFpFg8qt8cHPKj6';
  if (!bcrypt.compareSync(String(password || ''), user?.password_hash || dummy) || !user) fail('Invalid email or password', 401);
  const token = createSession(user);
  audit(user.id, user.id, 'auth.login', { portal: user.account_type === 'superadmin' ? 'admin_or_app' : 'app' });
  return { user: publicUser(user), token };
}
function listUsers() {
  return db.prepare(`SELECT u.*,COUNT(r.completed_at) AS reports_count,
    SUM(CASE WHEN r.completed_at IS NOT NULL AND r.mode='image' THEN 1 ELSE 0 END) AS scans_count,
    SUM(CASE WHEN r.completed_at IS NOT NULL AND r.mode='text' THEN 1 ELSE 0 END) AS manual_count
    FROM users u LEFT JOIN reports r ON r.user_id=u.id
    WHERE u.account_type!='superadmin' AND u.deleted_at IS NULL GROUP BY u.id ORDER BY u.created_at DESC`).all().map(publicUser);
}
function summary() {
  const users = listUsers();
  const counts = { total_users: users.length, labs: 0, persons: 0, trial_accounts: 0, subscription_accounts: 0, active_trials: 0, active_subscriptions: 0, expired: 0, stopped: 0, disabled: 0,
    reports_total: db.prepare('SELECT COUNT(*) AS count FROM reports WHERE completed_at IS NOT NULL').get().count,
    reports_scanned: db.prepare("SELECT COUNT(*) AS count FROM reports WHERE completed_at IS NOT NULL AND mode='image'").get().count,
    reports_manual: db.prepare("SELECT COUNT(*) AS count FROM reports WHERE completed_at IS NOT NULL AND mode='text'").get().count };
  users.forEach(u => {
    if (u.account_type === 'lab') counts.labs++; else counts.persons++;
    if (u.access_plan === 'trial') counts.trial_accounts++;
    if (u.access_plan === 'subscription') counts.subscription_accounts++;
    if (u.status === 'active' && u.access_plan === 'trial') counts.active_trials++;
    if (u.status === 'active' && u.access_plan === 'subscription') counts.active_subscriptions++;
    if (u.status === 'expired') counts.expired++;
    if (u.status === 'stopped') counts.stopped++;
    if (u.status === 'disabled') counts.disabled++;
  });
  return counts;
}
// Completed-report usage by login account, including archived (soft-deleted)
// accounts. This makes the visible totals reconcile with summary.reports_total.
function reportUsage() {
  return db.prepare(`SELECT u.id, u.display_name, u.email, u.account_type,
    (u.deleted_at IS NOT NULL) AS is_deleted,
    COUNT(r.id) AS reports_count,
    SUM(CASE WHEN r.mode='image' THEN 1 ELSE 0 END) AS scans_count,
    SUM(CASE WHEN r.mode='text' THEN 1 ELSE 0 END) AS manual_count,
    MAX(r.completed_at) AS last_report_at
    FROM users u
    LEFT JOIN reports r ON r.user_id = u.id AND r.completed_at IS NOT NULL
    WHERE u.account_type IN ('person','lab')
    GROUP BY u.id
    ORDER BY reports_count DESC, u.display_name COLLATE NOCASE ASC`).all().map(u => ({
      ...u, is_deleted: Boolean(u.is_deleted),
    }));
}
function reportHistory(accountId, limit = 50, offset = 0) {
  const account = db.prepare(`SELECT id,display_name,email,account_type,deleted_at
    FROM users WHERE id=? AND account_type IN ('person','lab')`).get(accountId);
  if (!account) fail('Account not found', 404);
  const safeLimit = Math.max(1, Math.min(100, Math.floor(Number(limit) || 50)));
  const safeOffset = Math.max(0, Math.floor(Number(offset) || 0));
  const reports = db.prepare(`SELECT id, mode, completed_at FROM reports
    WHERE user_id=? AND completed_at IS NOT NULL
    ORDER BY completed_at DESC, rowid DESC LIMIT ? OFFSET ?`)
    .all(accountId, safeLimit, safeOffset);
  const total = db.prepare(`SELECT COUNT(*) AS count FROM reports
    WHERE user_id=? AND completed_at IS NOT NULL`).get(accountId).count;
  return { account: { id: account.id, display_name: account.display_name,
      email: account.email, account_type: account.account_type,
      is_deleted: Boolean(account.deleted_at) },
    reports, total, limit: safeLimit, offset: safeOffset };
}
function listAudit(limit = 100, offset = 0) {
  const safeLimit = Math.max(1, Math.min(200, Number(limit) || 100));
  const safeOffset = Math.max(0, Number(offset) || 0);
  return db.prepare(`SELECT e.id,e.action,e.details_json,e.created_at,
    a.email AS actor_email,s.email AS subject_email,s.display_name AS subject_name
    FROM audit_events e LEFT JOIN users a ON a.id=e.actor_id LEFT JOIN users s ON s.id=e.subject_id
    ORDER BY e.created_at DESC,e.rowid DESC LIMIT ? OFFSET ?`).all(safeLimit,safeOffset).map(e => ({ ...e, details: JSON.parse(e.details_json), details_json: undefined }));
}
function authorizeReport(userId, mode) {
  if (!['image','text'].includes(mode)) fail('Invalid report mode');
  const user = userById(userId);
  if (!user || accessState(user) !== 'active' || user.account_type === 'superadmin') fail('Your trial or subscription is not active', 403);
  const id = randomUUID();
  const when = now();
  const expires = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  db.prepare('INSERT INTO reports (id,user_id,mode,created_at,expires_at) VALUES (?,?,?,?,?)')
    .run(id, userId, mode, when, expires);
  return { authorization_id: id, expires_at: expires };
}
function completeReport(userId, id) {
  const record = db.prepare('SELECT * FROM reports WHERE id=? AND user_id=?').get(id, userId);
  if (!record) fail('Report authorization not found', 404);
  if (record.completed_at) return { counted: true, already_recorded: true };
  if (record.expires_at <= now()) fail('Report authorization expired. Please analyze again', 403);
  const user = userById(userId);
  if (!user || accessState(user) !== 'active') fail('Your trial or subscription is not active', 403);
  db.transaction(() => {
    const updated = db.prepare('UPDATE reports SET completed_at=? WHERE id=? AND completed_at IS NULL').run(now(), id);
    if (updated.changes) audit(userId, userId, 'report.generated', { mode: record.mode, report_id: id });
  })();
  return { counted: true, already_recorded: false };
}
module.exports = { db, now, fail, userById, publicUser, audit, createUser, editUser, deleteUser, changePlan,
  createSession, findSession, revokeSession, revokeUserSessions, login, listUsers, summary, listAudit, reportUsage, reportHistory, authorizeReport, completeReport, ensurePassword };
