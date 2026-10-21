'use strict';
require('dotenv').config();
const path = require('node:path');
const { timingSafeEqual } = require('node:crypto');
const express = require('express');
const cookieParser = require('cookie-parser');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');
const core = require('./core');
const { accessState } = require('./time');

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 'loopback');
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '..', 'views'));
app.use(helmet());
app.use(express.json({ limit: '16kb' }));
// Profile pictures are resized in the browser and sent as a compact data URL.
app.use(express.urlencoded({ extended: false, limit: '768kb' }));
app.use(cookieParser());
app.use('/static', express.static(path.join(__dirname, '..', 'public'), { maxAge: '1d' }));
const authLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 12, standardHeaders: 'draft-7', legacyHeaders: false,
  message: { error: 'Too many login attempts. Try later.' } });
const writeLimit = rateLimit({ windowMs: 60 * 1000, limit: 120, standardHeaders: 'draft-7', legacyHeaders: false });
app.use('/api', writeLimit);

const tryRoute = (fn) => (req,res,next) => { try { const result = fn(req,res,next); if (result?.catch) result.catch(next); } catch (e) { next(e); } };
const bearerToken = req => {
  const header = req.get('authorization') || '';
  return header.startsWith('Bearer ') ? header.slice(7) : null;
};
const needAuth = tryRoute((req,res,next) => {
  const sessionInfo = core.findSession(bearerToken(req));
  if (!sessionInfo) core.fail('Please log in again', 401);
  req.auth = sessionInfo;
  next();
});
const needAdminApi = [needAuth, tryRoute((req,res,next) => {
  if (req.auth.user.account_type !== 'superadmin') core.fail('Superadmin access required', 403);
  next();
})];
const getTarget = req => {
  const u = core.userById(req.params.id);
  if (!u || u.account_type === 'superadmin') core.fail('User not found', 404);
  return u;
};

app.get('/health', (req,res) => res.json({ ok: true }));
app.post('/api/auth/login', authLimit, tryRoute((req,res) => {
  const data = core.login(req.body.email, req.body.password);
  res.json(data);
}));
app.get('/api/auth/me', needAuth, (req,res) => res.json({ user: core.publicUser(req.auth.user) }));
app.post('/api/auth/logout', needAuth, (req,res) => {
  core.revokeSession(bearerToken(req));
  res.json({ ok: true });
});
app.post('/api/auth/change-password', needAuth, tryRoute((req,res) => {
  const bcrypt = require('bcryptjs');
  if (!bcrypt.compareSync(String(req.body.old_password || ''), req.auth.user.password_hash)) core.fail('Current password is incorrect', 403);
  const password = core.ensurePassword(req.body.new_password);
  core.db.transaction(() => {
    core.db.prepare('UPDATE users SET password_hash=?,updated_at=? WHERE id=?').run(bcrypt.hashSync(password, 12), core.now(), req.auth.user.id);
    core.revokeUserSessions(req.auth.user.id);
    core.audit(req.auth.user.id, req.auth.user.id, 'auth.password_changed');
  })();
  res.json({ ok: true, relogin_required: true });
}));
app.post('/api/reports/authorize', needAuth, tryRoute((req,res) => {
  res.status(201).json(core.authorizeReport(req.auth.user.id, req.body.mode));
}));
app.post('/api/reports/:id/complete', needAuth, tryRoute((req,res) => {
  res.json(core.completeReport(req.auth.user.id, req.params.id));
}));

app.get('/api/admin/summary', ...needAdminApi, (req,res) => res.json(core.summary()));
app.get('/api/admin/users', ...needAdminApi, (req,res) => res.json({ users: core.listUsers() }));
app.get('/api/admin/users/:id', ...needAdminApi, tryRoute((req,res) => res.json({ user: core.publicUser(getTarget(req)) })));
app.post('/api/admin/users', ...needAdminApi, tryRoute((req,res) => res.status(201).json({ user: core.createUser(req.body,req.auth.user.id) })));
app.patch('/api/admin/users/:id', ...needAdminApi, tryRoute((req,res) => res.json({ user: core.editUser(req.params.id,req.body,req.auth.user.id) })));
app.delete('/api/admin/users/:id', ...needAdminApi, tryRoute((req,res) => {
  core.deleteUser(req.params.id, req.auth.user.id);
  res.json({ ok: true });
}));
app.post('/api/admin/users/:id/plan', ...needAdminApi, tryRoute((req,res) => res.json({ user: core.changePlan(req.params.id,req.body,req.auth.user.id) })));
app.get('/api/admin/audit', ...needAdminApi, (req,res) => res.json({ events: core.listAudit(req.query.limit,req.query.offset) }));
app.get('/api/admin/report-usage', ...needAdminApi, (req,res) => res.json({ accounts: core.reportUsage() }));
app.get('/api/admin/report-usage/:id', ...needAdminApi, tryRoute((req,res) =>
  res.json(core.reportHistory(req.params.id,req.query.limit,req.query.offset))));

const adminCookie = 'hemo_admin_session';
function setAdminCookie(res, token) {
  res.cookie(adminCookie, token, {
    httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict', path: '/admin', maxAge: 7 * 24 * 60 * 60 * 1000,
  });
}
function clearAdminCookie(res) { res.clearCookie(adminCookie, { path: '/admin', sameSite: 'strict', secure: process.env.NODE_ENV === 'production' }); }
const webAuth = tryRoute((req,res,next) => {
  const token = req.cookies[adminCookie];
  const found = core.findSession(token);
  if (!found || found.user.account_type !== 'superadmin') return res.redirect('/admin/login');
  req.webAuth = { ...found, token };
  res.locals.csrf = found.session.csrf_token;
  res.locals.adminEmail = found.user.email;
  res.locals.adminName = found.user.display_name;
  res.locals.adminProfileImage = found.user.profile_image_data || null;
  res.locals.notice = typeof req.query.notice === 'string' ? req.query.notice.slice(0,160) : '';
  res.locals.noticeType = req.query.notice_type === 'error' ? 'error' : 'success';
  next();
});
const csrf = tryRoute((req,res,next) => {
  const provided = typeof req.body.csrf === 'string' ? req.body.csrf : '';
  const expected = req.webAuth?.session.csrf_token || '';
  if (!provided || Buffer.byteLength(provided) !== Buffer.byteLength(expected) ||
      !timingSafeEqual(Buffer.from(provided), Buffer.from(expected))) core.fail('Invalid form token. Reload the page.', 403);
  next();
});
function webError(res, e, target) {
  res.redirect(`${target}?notice=${encodeURIComponent(e.message || 'Operation failed')}&notice_type=error`);
}
app.get('/', (req,res) => res.redirect('/admin'));
app.get('/admin/login', (req,res) => res.render('login', { error: null, email: '', loggedOut: req.query.signed_out === '1', passwordChanged: req.query.password_changed === '1' }));
app.post('/admin/login', authLimit, tryRoute((req,res) => {
  try {
    const { user, token } = core.login(req.body.email, req.body.password);
    if (user.account_type !== 'superadmin') {
      core.revokeSession(token);
      return res.status(403).render('login', { error: 'This portal is for superadmins only.', email: String(req.body.email || '').trim(), loggedOut: false, passwordChanged: false });
    }
    setAdminCookie(res, token);
    return res.redirect('/admin');
  } catch (e) { return res.status(e.status || 400).render('login', { error: e.message, email: String(req.body.email || '').trim(), loggedOut: false, passwordChanged: false }); }
}));
app.get('/admin', webAuth, (req,res) => res.render('dashboard', { page: 'dashboard', summary: core.summary(), users: core.listUsers() }));
app.get('/admin/profile', webAuth, (req,res) => res.render('profile', {
  page: 'profile', profile: core.adminProfile(req.webAuth.user)
}));
app.post('/admin/profile', webAuth, csrf, (req,res) => {
  try {
    core.updateAdminProfile(req.webAuth.user.id, req.body, req.webAuth.user.id);
    res.redirect('/admin/profile?notice=Profile+updated');
  } catch (e) { webError(res,e,'/admin/profile'); }
});
app.post('/admin/profile/password', webAuth, csrf, (req,res) => {
  try {
    core.changeAdminPassword(req.webAuth.user.id, req.body, req.webAuth.user.id);
    clearAdminCookie(res);
    res.redirect('/admin/login?password_changed=1');
  } catch (e) { webError(res,e,'/admin/profile'); }
});
app.get('/admin/audit', webAuth, (req,res) => res.render('audit', { page: 'audit', events: core.listAudit(200,req.query.offset), accounts: core.reportUsage(), offset: Number(req.query.offset) || 0 }));
app.get('/admin/reports', webAuth, (req,res) => res.render('reports', { page: 'reports', accounts: core.reportUsage(), summary: core.summary() }));
app.get('/admin/reports/:id', webAuth, tryRoute((req,res) => res.render('report_detail', {
  page: 'reports', ...core.reportHistory(req.params.id, 50, req.query.offset)
})));
app.get('/admin/users/new', webAuth, (req,res) => res.render('account', { page: 'accounts', user: null }));
app.get('/admin/users/:id/edit', webAuth, tryRoute((req,res) => res.render('account', { page: 'accounts', user: core.publicUser(getTarget(req)) })));
app.get('/admin/users/:id/delete', webAuth, tryRoute((req,res) => res.render('delete', { page: 'accounts', user: core.publicUser(getTarget(req)) })));
app.get('/admin/users/:id/plan', webAuth, tryRoute((req,res) => res.render('plan', { page: 'accounts', user: core.publicUser(getTarget(req)) })));
app.post('/admin/users', webAuth, csrf, (req,res) => {
  try { core.createUser(req.body,req.webAuth.user.id); res.redirect('/admin?notice=Account+created'); }
  catch(e) { webError(res,e,'/admin/users/new'); }
});
app.post('/admin/users/:id/edit', webAuth, csrf, (req,res) => {
  try { core.editUser(req.params.id,req.body,req.webAuth.user.id); res.redirect('/admin?notice=Account+updated'); }
  catch(e) { webError(res,e,`/admin/users/${encodeURIComponent(req.params.id)}/edit`); }
});
app.post('/admin/users/:id/plan', webAuth, csrf, (req,res) => {
  try { core.changePlan(req.params.id,req.body,req.webAuth.user.id); res.redirect('/admin?notice=Plan+updated'); }
  catch(e) { webError(res,e,`/admin/users/${encodeURIComponent(req.params.id)}/plan`); }
});
app.post('/admin/users/:id/delete', webAuth, csrf, (req,res) => {
  try { core.deleteUser(req.params.id,req.webAuth.user.id); res.redirect('/admin?notice=Account+deleted'); }
  catch(e) { webError(res,e,'/admin'); }
});
app.post('/admin/logout', webAuth, csrf, (req,res) => {
  core.revokeSession(req.webAuth.token);
  clearAdminCookie(res);
  res.redirect('/admin/login?signed_out=1');
});

app.use('/api', (req,res) => res.status(404).json({ error: 'Not found' }));
app.use((req,res) => res.status(404).send('Not found'));
app.use((e,req,res,next) => {
  const status = e.status || 500;
  if (status >= 500) console.error('Server error:', e);
  if (req.path.startsWith('/api')) return res.status(status).json({ error: status >= 500 ? 'Internal server error' : e.message });
  return res.status(status).send(status >= 500 ? 'Internal server error' : e.message);
});

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  app.listen(port, '127.0.0.1', () => console.log(`Hemo Guard server listening on 127.0.0.1:${port}`));
}
module.exports = app;
