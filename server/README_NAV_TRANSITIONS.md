# HemoGuard Smooth Navigation Update

This patch builds on the Superadmin Profile & Security version and changes only the primary admin navigation experience.

## What changed

- Accounts, Reports and Audit are now persistent glass blocks.
- The active destination becomes transparent/open instead of receiving an extra active block.
- A thin violet-magenta-rose focus rail glides smoothly between destinations.
- Accounts → Reports → Audit moves left-to-right.
- Audit → Reports → Accounts moves right-to-left.
- The current page fades/slides out before the existing server route loads.
- The destination page fades/slides in from the matching direction.
- Ctrl/Cmd-click, middle-click and other normal browser link behaviors remain available.
- Reduced-motion preferences disable the animation automatically.
- The profile/security feature, logout flow, backend routes and database logic are unchanged.

## Files changed

- `views/header.ejs`
- `public/admin.css`
- `public/admin.js`
- `test/ui.test.js`

## Install

Copy the patch files over the corresponding files in your working `server/` directory. Do not replace `.env` or `data/`. Restart the Node server, then hard refresh once (`Ctrl+F5`).

No npm packages or database migrations are required for this update.
