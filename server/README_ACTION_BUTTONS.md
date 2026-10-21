# HemoGuard themed action controls

This UI-only update restyles the Account Directory actions and Reports history link.

## Changed files

- `public/admin.css`
- `views/dashboard.ejs`
- `views/reports.ejs`
- `test/ui.test.js`

## Visual behavior

- **Reports**: violet liquid-glass button
- **Edit**: violet-to-magenta liquid-glass button
- **Plan**: magenta-to-pink liquid-glass button
- **Delete**: rose/red liquid-glass button with destructive emphasis
- **View history**: full violet-magenta-rose glass CTA button

No routes, authentication, database code, report counting, profile/security logic, or smooth navigation behavior were changed.

After copying the patch, restart the server and use `Ctrl + F5` once if the browser has cached the old CSS.
