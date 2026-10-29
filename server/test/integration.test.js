'use strict';
// Runs after npm install. Uses a private temporary SQLite DB and a random port.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const bcrypt = require('bcryptjs');
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hemo-test-'));
process.env.DATABASE_PATH = path.join(tempDir, 'test.sqlite');
process.env.NODE_ENV = 'test';
const core = require('../src/core');
const app = require('../src/server');
let server;
let host;
let adminToken;
let userToken;
let userId;
const json = async (method, url, token, body) => {
  const response = await fetch(host + url, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: response.status, data: await response.json() };
};
test.before(async () => {
  const at = core.now();
  await core.db.prepare(`INSERT INTO users(id,display_name,email,account_type,password_hash,is_active,created_at,updated_at)
     VALUES(?,?,?,?,?,1,?,?)`).run(randomUUID(), 'Admin', 'admin@test.invalid', 'superadmin',
     bcrypt.hashSync('example-pass-12345', 12), at, at);
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  host = `http://127.0.0.1:${server.address().port}`;
});
test.after(async () => {
  if (server) await new Promise(resolve => server.close(resolve));
  await core.db.close();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
test('unauthorized API access is denied', async () => {
  const s = await json('GET','/api/admin/summary');
  assert.equal(s.status, 401);
  const r = await json('POST','/api/reports/authorize',null,{mode:'text'});
  assert.equal(r.status, 401);
});
test('admin creates trial, user signs in, report completion counted once, admin sees audit', async () => {
  const a = await json('POST', '/api/auth/login', null,
    { email:'admin@test.invalid', password:'example-pass-12345' });
  assert.equal(a.status,200);
  adminToken = a.data.token;
  const created = await json('POST', '/api/admin/users', adminToken, {
    display_name:'Central Lab', email:'lab@test.invalid', password:'lab-secure-pass-123',
    account_type:'lab', access_plan:'trial', duration:14, unit:'days',
  });
  assert.equal(created.status,201,JSON.stringify(created.data));
  userId = created.data.user.id;
  const u = await json('POST','/api/auth/login',null,
    { email:'lab@test.invalid', password:'lab-secure-pass-123' });
  assert.equal(u.status,200);
  assert.equal(u.data.user.access_plan, 'trial');
  assert.equal(u.data.user.status, 'active');
  assert.equal(u.data.user.days_remaining, 14);
  userToken = u.data.token;
  const notAdmin = await json('GET','/api/admin/users',userToken);
  assert.equal(notAdmin.status,403);
  const start = await json('POST','/api/reports/authorize',userToken,{mode:'image'});
  assert.equal(start.status,201);
  const finish = await json('POST',`/api/reports/${start.data.authorization_id}/complete`,userToken);
  assert.equal(finish.status,200);
  const again = await json('POST',`/api/reports/${start.data.authorization_id}/complete`,userToken);
  assert.equal(again.status,200);
  assert.equal(again.data.already_recorded,true);
  const stats = await json('GET','/api/admin/summary',adminToken);
  assert.equal(stats.data.reports_total,1);
  assert.equal(stats.data.reports_scanned,1);
  assert.equal(stats.data.labs,1);
  assert.equal(stats.data.active_trials,1);
  const users = await json('GET','/api/admin/users',adminToken);
  assert.equal(users.data.users[0].reports_count,1);
  assert.equal(users.data.users[0].scans_count,1);
  assert.equal(users.data.users[0].password_hash,undefined);
  const audit = await json('GET','/api/admin/audit',adminToken);
  assert.ok(audit.data.events.some(e => e.action === 'report.generated'));
  const usage = await json('GET','/api/admin/report-usage',adminToken);
  assert.equal(usage.status,200);
  assert.equal(usage.data.accounts.length,1);
  assert.equal(usage.data.accounts[0].id,userId);
  assert.equal(usage.data.accounts[0].account_type,'lab');
  assert.equal(usage.data.accounts[0].reports_count,1);
  assert.equal(usage.data.accounts[0].scans_count,1);
  assert.equal(usage.data.accounts[0].manual_count,0);
  assert.ok(usage.data.accounts[0].last_report_at);
  const history = await json('GET',`/api/admin/report-usage/${userId}`,adminToken);
  assert.equal(history.status,200);
  assert.equal(history.data.total,1);
  assert.equal(history.data.reports.length,1);
  assert.equal(history.data.reports[0].mode,'image');
  assert.equal(history.data.reports[0].id,start.data.authorization_id);
  assert.deepEqual(Object.keys(history.data.reports[0]).sort(), ['completed_at','id','mode']);
  const page2 = await json('GET',`/api/admin/report-usage/${userId}?limit=1&offset=1`,adminToken);
  assert.equal(page2.status,200);
  assert.equal(page2.data.total,1);
  assert.equal(page2.data.reports.length,0);
  const notAllowed = await json('GET','/api/admin/report-usage',userToken);
  assert.equal(notAllowed.status,403);
  const notAllowedHistory = await json('GET',`/api/admin/report-usage/${userId}`,userToken);
  assert.equal(notAllowedHistory.status,403);
  const missing = await json('GET','/api/admin/report-usage/nonexistent',adminToken);
  assert.equal(missing.status,404);
});
test('stop trial blocks report; subscription conversion and expiry enforced', async () => {
  let state = await json('POST',`/api/admin/users/${userId}/plan`,adminToken,{action:'stop_trial'});
  assert.equal(state.status,200);
  assert.equal(state.data.user.status,'stopped');
  assert.equal(state.data.user.days_remaining, 0);
  let report = await json('POST','/api/reports/authorize',userToken,{mode:'text'});
  assert.equal(report.status,403);
  state = await json('POST',`/api/admin/users/${userId}/plan`,adminToken,
    {action:'set_subscription',duration:1,unit:'months'});
  assert.equal(state.status,200);
  assert.equal(state.data.user.status,'active');
  report = await json('POST','/api/reports/authorize',userToken,{mode:'text'});
  assert.equal(report.status,201);
  await core.db.prepare('UPDATE users SET plan_expires_at=? WHERE id=?').run('2020-01-01T00:00:00.000Z',userId);
  const blockedCompletion = await json('POST',`/api/reports/${report.data.authorization_id}/complete`,userToken);
  assert.equal(blockedCompletion.status,403);
  const stats = await json('GET','/api/admin/summary',adminToken);
  assert.equal(stats.data.reports_total,1);
  assert.equal(stats.data.expired,1);
  const expired = await json('GET','/api/auth/me',userToken);
  assert.equal(expired.data.user.days_remaining,0);
  state = await json('POST',`/api/admin/users/${userId}/plan`,adminToken,
    {action:'extend_subscription',duration:30,unit:'days'});
  assert.equal(state.status,200);
  assert.equal(state.data.user.status,'active');
});
test('deleting an account revokes sessions but preserves historical totals', async () => {
  const deleted = await json('DELETE',`/api/admin/users/${userId}`,adminToken);
  assert.equal(deleted.status,200);
  const result = await json('GET','/api/auth/me',userToken);
  assert.equal(result.status,401);
  const stats = await json('GET','/api/admin/summary',adminToken);
  assert.equal(stats.data.total_users,0);
  assert.equal(stats.data.reports_total,1);
  const usage = await json('GET','/api/admin/report-usage',adminToken);
  assert.equal(usage.status,200);
  assert.equal(usage.data.accounts.length,1);
  assert.equal(usage.data.accounts[0].is_deleted,true);
  assert.equal(usage.data.accounts[0].reports_count,1);
  const history = await json('GET',`/api/admin/report-usage/${userId}?limit=1&offset=0`,adminToken);
  assert.equal(history.status,200);
  assert.equal(history.data.account.is_deleted,true);
  assert.equal(history.data.total,1);
});
test('individual report count is separate from an archived lab and report pages render', async () => {
  const created = await json('POST','/api/admin/users',adminToken,{
    display_name:'Ali',email:'ali@test.invalid',password:'person-secure-pass-123',
    account_type:'person',access_plan:'subscription',duration:1,unit:'months',
  });
  assert.equal(created.status,201);
  const personLogin = await json('POST','/api/auth/login',null,{
    email:'ali@test.invalid',password:'person-secure-pass-123',
  });
  assert.equal(personLogin.status,200);
  assert.equal(personLogin.data.user.access_plan,'subscription');
  assert.ok(personLogin.data.user.days_remaining >= 28);
  const start = await json('POST','/api/reports/authorize',personLogin.data.token,{mode:'text'});
  assert.equal(start.status,201);
  assert.equal((await json('POST',`/api/reports/${start.data.authorization_id}/complete`,personLogin.data.token)).status,200);
  const usage = await json('GET','/api/admin/report-usage',adminToken);
  assert.equal(usage.status,200);
  assert.equal(usage.data.accounts.length,2);
  const person = usage.data.accounts.find(a => a.id === created.data.user.id);
  const lab = usage.data.accounts.find(a => a.id === userId);
  assert.equal(person.reports_count,1);
  assert.equal(person.manual_count,1);
  assert.equal(lab.reports_count,1);
  assert.equal(lab.scans_count,1);
  assert.equal(lab.is_deleted,true);
  const summary = await json('GET','/api/admin/summary',adminToken);
  assert.equal(summary.data.reports_total,2);
  const webLogin = await fetch(host+'/admin/login',{
    method:'POST',redirect:'manual',
    headers: {'Content-Type':'application/x-www-form-urlencoded'},
    body: new URLSearchParams({email:'admin@test.invalid',password:'example-pass-12345'}),
  });
  assert.equal(webLogin.status,302);
  const cookie = webLogin.headers.get('set-cookie').split(';')[0];
  const html = await fetch(host+'/admin/reports',{headers:{Cookie:cookie}});
  assert.equal(html.status,200);
  const text = await html.text();
  assert.match(text,/Central Lab/);
  assert.match(text,/Ali/);
  const detail = await fetch(host+`/admin/reports/${created.data.user.id}`,{headers:{Cookie:cookie}});
  assert.equal(detail.status,200);
  assert.match(await detail.text(),/Completed report history/);
  const auditPage = await fetch(host+'/admin/audit',{headers:{Cookie:cookie}});
  assert.equal(auditPage.status,200);
  const auditHtml = await auditPage.text();
  assert.match(auditHtml,/Who generated how many reports/);
  assert.match(auditHtml,/Central Lab/);
});
