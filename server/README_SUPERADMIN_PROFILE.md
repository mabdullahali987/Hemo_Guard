# HemoGuard Superadmin Profile & Security

This update adds self-service profile management for the signed-in superadmin without changing the existing user/lab management, trial/subscription, report-counting, or audit workflows.

## New capabilities

The superadmin can open **Profile & security** from the profile chip in the top-right navigation and can:

- change their display name;
- change their login email;
- choose or remove a profile picture;
- change their password after confirming the current password.

A password change revokes all existing sessions for that superadmin and redirects back to the login screen. The new password must be used to sign in again.

## Profile picture handling

No new npm upload dependency is required. The browser:

1. accepts PNG, JPEG, or WebP;
2. rejects files larger than 5 MB before processing;
3. center-crops and resizes the image to 384 x 384;
4. converts it to a compact JPEG data URL;
5. submits the processed image with the normal protected form.

The server validates the resulting data URL and limits the decoded image to 300 KB. The image is stored in the existing SQLite database on the superadmin's user record.

## Database migration

On first server start, `src/db.js` checks the existing `users` table and adds this nullable column if needed:

```sql
profile_image_data TEXT
```

Existing users, reports, trials, subscriptions, sessions, and audit history are not deleted or recreated.

## Updated files

- `src/db.js`
- `src/core.js`
- `src/server.js`
- `views/header.ejs`
- `views/login.ejs`
- `views/profile.ejs` (new)
- `public/admin.css`
- `public/admin.js`
- `test/ui.test.js`

## Installation into an existing working server

1. Back up the entire `server/` folder and especially `server/data/hemo-guard.sqlite` and `.env`.
2. Stop the Node.js server.
3. Copy the updated files above into the matching locations.
4. Do **not** replace your live `server/data/` directory or `.env`.
5. Start the server:

```powershell
npm start
```

6. Sign in and click the profile control in the top-right corner.
7. If the old JavaScript/CSS remains cached, press `Ctrl + F5` once.

No `npm install` is required specifically for this feature because no new package dependency was added.

## Security behavior

- All profile routes require the existing superadmin web session.
- All profile forms retain the existing CSRF validation.
- Email uniqueness is enforced by the existing database constraint.
- Password changes require the current password.
- Passwords remain bcrypt-hashed and are never displayed.
- Changing the password revokes all sessions for that superadmin.
- Profile picture MIME type, decoded size, and file signature are validated by the server.
- Profile picture data is excluded from normal `publicUser()` API responses to avoid sending the image through unrelated app APIs.
- Profile changes and password changes are recorded in the existing audit table.

## Validation performed

`node --check` passed for the modified JavaScript files. The standalone UI/date test suite passed 11/11 tests in the packaging environment.

The full integration test suite could not run in the packaging environment because the uploaded `node_modules/better-sqlite3` contains a Windows native binary, which cannot load on Linux. Run `npm test` on the Windows machine where this server normally runs.
