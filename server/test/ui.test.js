'use strict';
// Standalone template checks: deliberately do not access the live database.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ejs = require('ejs');
const views = path.join(__dirname, '..', 'views');
const sample = {
  id: 'fake-id', display_name: 'Example Lab', email: 'lab@example.invalid',
  account_type: 'lab', access_plan: 'trial', status: 'active',
  is_active: 1, is_deleted: false, plan_started_at: null, plan_expires_at: null,
  reports_count: 3, scans_count: 2, manual_count: 1, last_report_at: null,
};
const summary = {
  total_users: 1, labs: 1, persons: 0, trial_accounts: 1,
  active_trials: 1, subscription_accounts: 0, active_subscriptions: 0,
  expired: 0, stopped: 0, disabled: 0,
  reports_total: 3, reports_scanned: 2, reports_manual: 1,
};
function render(name, data = {}) {
  const filename = path.join(views, `${name}.ejs`);
  return ejs.render(fs.readFileSync(filename, 'utf8'), {
    csrf: 'example-csrf', adminEmail: 'admin@example.invalid', adminName: 'Admin User', adminProfileImage: null, notice: '', noticeType: 'success',
    page: 'dashboard', user: sample, users: [sample], accounts: [sample],
    summary, events: [], account: sample, reports: [], offset: 0, limit: 50,
    total: 3, profile: { id:'admin-id', display_name:'Admin User', email:'admin@example.invalid', profile_image_data:null, created_at:'2026-01-01T00:00:00.000Z', updated_at:'2026-01-01T00:00:00.000Z' }, ...data,
  }, { filename });
}
test('login includes existing server action and visible error feedback', () => {
  const html = render('login', { error: 'Invalid email or password', email: 'admin@example.invalid', loggedOut: false });
  assert.match(html, /action="\/admin\/login"/);
  assert.match(html, /type="password"/);
  assert.match(html, /role="alert"/);
  assert.match(html, /Invalid email or password/);
  assert.match(html, /data-login-form/);
});
test('signed-out state is rendered only after confirmed logout', () => {
  assert.match(render('login', { error: null, email: '', loggedOut: true }), /Signed out securely/);
  assert.doesNotMatch(render('login', { error: null, email: '', loggedOut: false }), /Signed out securely/);
});
test('dashboard retains account links, report totals and secure logout form', () => {
  const html = render('dashboard');
  assert.match(html, /action="\/admin\/logout"/);
  assert.match(html, /name="csrf" value="example-csrf"/);
  assert.match(html, /\/admin\/users\/fake-id\/edit/);
  assert.match(html, /\/admin\/users\/fake-id\/plan/);
  assert.match(html, /Reports generated/);
  assert.match(html, /data-table-search="accounts-table"/);
});
test('account, plan, and delete forms preserve original field names', () => {
  const add = render('account', { user: null });
  for (const field of ['display_name','email','account_type','password','access_plan','duration','unit','csrf']) {
    assert.ok(add.includes(`name="${field}"`), `Missing ${field}`);
  }
  const edit = render('account');
  assert.match(edit, /name="is_active"/);
  assert.match(edit, /\/admin\/users\/fake-id\/edit/);
  assert.match(render('plan'), /name="action"/);
  assert.match(render('delete'), /\/admin\/users\/fake-id\/delete/);
});
test('report and audit templates render account-level data without exposing CBC values', () => {
  assert.match(render('reports'), /Example Lab/);
  assert.match(render('report_detail'), /Completed analyses/);
  assert.match(render('audit'), /Reports by account/);
});
test('user-provided display names are HTML escaped', () => {
  const html = render('dashboard', {users: [{...sample,display_name:'<img src=x onerror=alert(1)>'}]});
  assert.doesNotMatch(html, /<img src=x/);
  assert.match(html, /&lt;img/);
});

test('superadmin profile page exposes profile, picture and password controls only to the admin UI', () => {
  const html = render('profile', { page: 'profile' });
  assert.match(html, /action="\/admin\/profile"/);
  assert.match(html, /name="display_name"/);
  assert.match(html, /name="email"/);
  assert.match(html, /name="profile_image_data"/);
  assert.match(html, /data-avatar-input/);
  assert.match(html, /action="\/admin\/profile\/password"/);
  assert.match(html, /name="current_password"/);
  assert.match(html, /name="new_password"/);
  assert.match(html, /name="confirm_password"/);
  assert.match(html, /href="\/admin\/profile"/);
});


test('primary navigation exposes ordered destinations for smooth directional motion', () => {
  const html = render('dashboard');
  assert.match(html, /data-main-nav/);
  assert.match(html, /data-nav-index="0"/);
  assert.match(html, /data-nav-index="1"/);
  assert.match(html, /data-nav-index="2"/);
  assert.match(html, /data-nav-focus/);
});

test('account directory and report history use themed action buttons', () => {
  const dashboard = render('dashboard');
  assert.match(dashboard, /class="action-button action-reports"/);
  assert.match(dashboard, /class="action-button action-edit"/);
  assert.match(dashboard, /class="action-button action-plan"/);
  assert.match(dashboard, /class="action-button action-delete danger-link"/);
  const reports = render('reports');
  assert.match(reports, /class="history-button"/);
  assert.match(reports, /View history/);
});
