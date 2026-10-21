# HemoGuard Pearl Liquid-Glass Admin UI

This release redesigns the **web superadmin interface only**. It keeps the existing Node.js routes, authentication, CSRF protection, SQLite schema, account logic, subscriptions/trials, report counts, and audit behavior intact.

## Design direction

The interface follows a task-first HCI approach instead of a marketing-page approach:

- **Focused login:** one clear task — authenticate. No promotional split panel.
- **Visible system status:** loading states, success notices, login errors, logout confirmation, and a secure sign-out transition.
- **Consistency:** one component language for buttons, fields, tables, status pills, cards, and dialogs.
- **Recognition over recall:** navigation and actions stay visible and use predictable labels.
- **Error prevention:** destructive actions remain separated and plan/account forms explain the consequence of important choices.
- **Readable hierarchy:** primary action first, secondary actions quieter, high-contrast text, generous spacing, and responsive tables.
- **Accessibility:** keyboard focus states, semantic alerts/dialogs, touch-friendly controls, and reduced-motion support.

The visual language is intentionally **light**: white/translucent glass, pearl backgrounds, violet → magenta → rose accents, and no navy/blue UI theme.

## Logo replacement

The current placeholder logo is:

```text
server/public/hemoguard-logo.svg
```

It is used in:

```text
server/views/login.ejs
server/views/header.ejs
server/views/footer.ejs
```

### Easiest option

Replace `public/hemoguard-logo.svg` with your real **SVG logo** using the same filename. No template changes are required.

### If your logo is PNG / WebP

Copy it into `server/public/`, for example:

```text
server/public/hemoguard-logo.png
```

Then change this path in the three templates above:

```html
src="/static/hemoguard-logo.svg"
```

to:

```html
src="/static/hemoguard-logo.png"
```

For best results use a transparent-background logo with a square or near-square canvas.

## Files changed for this UI release

```text
public/admin.css
public/admin.js
public/hemoguard-logo.svg       # new placeholder logo
views/login.ejs
views/header.ejs
views/footer.ejs
views/dashboard.ejs
views/account.ejs
views/plan.ejs
test/ui.test.js
README_UI_UPGRADE.md
```

Other EJS pages automatically inherit the new visual system through `header.ejs`, `footer.ejs`, and `admin.css`.

## Safe installation on your existing working server

1. Back up your working `server/` directory.
2. **Do not replace** your existing `.env` or SQLite database.
3. Copy the changed files above into the matching locations.
4. Restart the server.
5. Hard-refresh the browser (`Ctrl + F5`) so the new CSS is loaded.

PowerShell example:

```powershell
cd server
npm test
npm start
```

Then open:

```text
http://localhost:3000/admin/login
```

## Logout experience

Clicking **Sign out** now opens a keyboard-accessible confirmation dialog. Confirming shows a short liquid-glass transition while the normal server logout request runs. The server still revokes the session and clears the cookie; the animation does not replace security behavior.

## Login errors

Incorrect credentials continue to use the backend's generic `Invalid email or password` response. This is intentionally generic so the UI does not reveal whether a particular email address exists. The error is now presented as a prominent inline glass alert with motion feedback and accessible `role="alert"` semantics.

## Production note

No third-party UI/CDN dependency is required. The interface uses local CSS, JavaScript, and the local logo asset, so it works on a VPS without relying on external design services.
