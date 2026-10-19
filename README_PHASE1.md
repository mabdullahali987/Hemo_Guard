# Hemo Guard — Phase 1 delivery (authentication, superadmin, auditing)

This package updates the uploaded Flutter `lib/` source tree and adds a Node.js + EJS + SQLite server in `server/`. The original CBC OCR, parsing, predictor, scan view, result layout, and theme remain unchanged (aside from an essential sign-out button and counting at the existing prediction call site).

**The original upload was only `lib/`, not a complete Flutter project.** Accordingly, this ZIP does not pretend to contain your original `pubspec.yaml`, Android/iOS projects, `assets/logo.png`, or `assets/xgboast.json`. Merge `lib/` into the original app and retain its assets and existing dependencies. Flutter compilation was not possible in this environment because the Flutter/Dart SDK and the rest of the app are not present.

## Features delivered

- **Superadmin**: create/edit/soft-delete accounts; account type `person` or `lab` (one account/login for a lab); login email and initial password; enable/disable accounts; reset passwords; start/extend/stop trials in days; start/switch/extend/stop subscriptions in days or calendar months. Existing session tokens are revoked when a password changes, an account is disabled, or an account is deleted.
- **Admin website**: EJS interface at `/admin/login` and `/admin`, responsive on phones; audit log at `/admin/audit`; shows live and expired access metrics, per-account report counts, and scan/manual splits.
- **Mobile admin**: a superadmin can sign in through the Flutter login form and use the native Superadmin screen for account management, plan operations, analytics, and audit-history pagination.
- **Login**: same email/password for individuals and labs; credentials provisioned by superadmin. Access state is checked on the server when generating each analysis. Client tokens stored in `flutter_secure_storage` (Android Keystore / iOS Keychain).
- **Audit**: logs account, plan, login, password-change and completed-report events. Counts each *completed* analysis once, even if the completion request is retried. Per-account report counts are stored permanently (including after account deletion). Neither patient report images nor CBC fields are sent to the server.

## 1. Deploy the backend on an Ubuntu VPS

Prerequisites: Node.js >=20, an internet connection for `npm install`, Nginx, and a domain with a valid HTTPS certificate. SQLite needs a **persistent writable and backed-up directory**. Current production workloads with modest write concurrency can use SQLite; consider PostgreSQL if the service scales substantially.

```bash
cd server
npm install
cp .env.example .env
# Edit .env: NODE_ENV=production, DATABASE_PATH=/var/lib/hemo-guard/hemo.sqlite
# Create the DB directory and ensure it is owned by the service account.
# For the one-time bootstrap, provide credentials through the shell environment:
ADMIN_EMAIL='owner@example.com' ADMIN_PASSWORD='long-unique-secret-password' npm run bootstrap-admin
npm test
npm start
```

**Never use the example credentials in production.** Run bootstrap once only; it refuses to overwrite an existing superadmin. Do not expose the Node port publicly. The Node process listens on `127.0.0.1:3000`, behind Nginx. Keep `/var/lib/hemo-guard` outside the web root; backups must include `hemo.sqlite` and any active SQLite WAL files or use SQLite's online backup API.

Example Nginx site (`server/deploy/nginx.conf.example`): configure TLS using Let's Encrypt, then reverse proxy `/` to Node. Use `server/deploy/hemo-guard.service.example` with a dedicated unprivileged service user for systemd.

## 2. Merge Flutter sources

1. Keep your original Flutter project, including `pubspec.yaml`, `assets/`, platform directories, OCR packages, and model assets.
2. Copy the provided `lib/` folder over your existing `lib/` folder. No existing algorithm files were intentionally changed.
3. Add **one new dependency** to the existing Flutter project:

   ```bash
   flutter pub add flutter_secure_storage
   flutter pub get
   ```

4. Verify your platform has network permissions. Android apps typically need `<uses-permission android:name="android.permission.INTERNET"/>` in the main manifest; iOS must allow HTTPS connections. Flutter Secure Storage's platform setup (e.g. Keychain entitlements if required) must also be followed.
5. Build the mobile app with the public HTTPS address of your server:

   ```bash
   flutter run --dart-define=API_BASE_URL=https://your-domain.example
   flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.example
   ```

6. Sign in as the bootstrap superadmin to open the native mobile admin view, or visit `https://your-domain.example/admin/login` from any browser.
7. In the admin portal, create a lab or individual with an initial password and active trial/subscription. Give credentials to that user over a secure channel. Their app will open the existing Home screen after login.

During emulator-only **debug** development, HTTP is permitted for `localhost`, `127.0.0.1`, and `10.0.2.2`. Production builds require HTTPS. The HTTPS certificate must be trusted by the device.

## How report counts work

The existing analysis button and successful auto-analysis (after a complete scan) both call `runPrediction()`:

1. Client sends `POST /api/reports/authorize` with just `mode=image|text`; server checks session and access status, then creates a short-lived authorization ID.
2. Existing on-device model predicts from CBC values locally. There are **no server uploads of CBC values, patient names, images, or model outputs**.
3. Client calls `POST /api/reports/:id/complete`; server rechecks access, records one completed report plus audit event, and then the app shows the prediction.
4. Network/server problems cause the client to withhold a new result rather than bypass licensing or fail to record it. An abandoned/failed prediction does not increment the report count. The server's complete endpoint is idempotent.

As with any on-device prediction model, a technically modified client can bypass client-side checks or falsely report completed analyses. Absolute prevention of tampering would require server-side inference or hardware-backed attestation. This design enforces access and trustworthy counts for the unmodified official app. The data audit is **usage reporting**, not an immutable or regulatory-grade medical audit trail.

## API endpoints

| Endpoint | Caller | Behavior |
| --- | --- | --- |
| `POST /api/auth/login` | all | Email/password → bearer token, user state |
| `GET /api/auth/me` | signed in | Current role/plan state |
| `POST /api/auth/logout` | signed in | Revoke current token |
| `POST /api/auth/change-password` | signed in | Change password and revoke sessions |
| `POST /api/reports/authorize` | active person/lab | Reserve analysis without sending medical data |
| `POST /api/reports/:id/complete` | active person/lab | Idempotently count a completed analysis |
| `GET /api/admin/summary` | superadmin | Counts by account, active plan, and completed reports |
| `GET/POST /api/admin/users` | superadmin | List/create accounts |
| `GET/PATCH/DELETE /api/admin/users/:id` | superadmin | Read/edit/soft-delete account |
| `POST /api/admin/users/:id/plan` | superadmin | Set, extend, stop trials/subscriptions |
| `GET /api/admin/audit?limit=100&offset=0` | superadmin | Paginated event log |

Plan actions: `set_trial`, `extend_trial`, `stop_trial`, `set_subscription`, `extend_subscription`, `stop_subscription`. Duration is a positive integer; use `days` for a trial, `days` or `months` for a subscription. Time periods are calculated in UTC and expire exactly at the stored instant, not at the next midnight. Month arithmetic clamps to the last day of shorter months.

## Security / hosting checklist

- Protect VPS and `.env`, use TLS at Nginx, block public access to port 3000, and patch the OS and Node dependencies.
- SQLite should be writable only by the server service user, and included in encrypted backups.
- Passwords are bcrypt-hashed, minimum 12 characters; session tokens are randomly generated, stored as SHA-256 hashes in SQLite, valid up to 7 days; mobile tokens live in secure device storage. Browser admin sessions use HttpOnly, SameSite=Strict cookies, HTTPS-only in production, and CSRF tokens for all admin write forms.
- The server authorizes all admin operations and all report actions independently of Flutter navigation. It disables/report-blocks expired/stopped accounts and invalidates sessions on deactivation, deletion, or password reset. Authentication requests are rate-limited.
- **Payment processing is not included:** subscription means an admin-assigned, time-limited permission, exactly as requested. It does not automatically bill users.
- To support separate staff members at the same lab, future work would need organization membership and staff user accounts. Currently `lab` denotes an account type for a single login email.
- This phase intentionally does **not** include the later glassmorphism UI redesign.

## Validation notes

- JavaScript syntax checks and the standalone expiry/month-arithmetic tests can run with Node.
- Backend integration tests covering permissions, login, counts, stop/extend/convert and deletion are in `server/test/integration.test.js`. Run `npm install && npm test` on a network-connected machine or VPS.
- A full Flutter APK build and a complete live-server integration test require the missing Flutter project files and installable Node dependencies, respectively. Neither is claimed to have been performed here.
