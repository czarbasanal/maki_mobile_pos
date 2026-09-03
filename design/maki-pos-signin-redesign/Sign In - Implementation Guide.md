# Sign In — Implementation Guide

Reference implementation: `Sign In.dc.html`
Skin, tokens and shared components: `Dashboard - Spec.md`. Read that first; everything here
assumes its §2 tokens, §7 component library and §4 theme rules.

---

## 1. What changed and why

The old screen was an unstyled form floating on pure white: no card, no brand, fields
spanning ~770px, and a pure-black `Sign in` button — the only black element in the product
and off-palette. Nothing tied it to the app the user was about to enter.

Changes:

1. **The form sits in a card.** Surface fill, `1px --border`, radius 16px, `--shadow-lg`,
   on the app's `--bg` rather than white. It reads as the same product as the dashboard.
2. **Fields are 392px, not 770px.** An email is ~30 characters; a field three times that
   wide makes the form feel unfinished.
3. **The button is the standard amber primary**, matching every other primary action.
4. **Brand mark is amber and holds the M** in mono, same as the sidebar mark — 44px here
   instead of 34px, since it is the only mark on the page.
5. **Added:** inline error state, password show/hide, `Keep me signed in`, a loading button
   label, and the light/dark toggle. `Forgot password?` moved up beside the checkbox so the
   button is the last thing before the footer.

Copy is unchanged: `MAKI POS Admin`, `Sign in to continue`, `Email`, `Password`, `Sign in`,
`Forgot password?`, `v1.0.0`.

---

## 2. Layout

One centered column, no split panel, no illustration.

```
page: flex column; align-items:center; padding:28px 24px 32px; min-height:100vh
  ├ theme toggle      — 392px wide row, right-aligned
  ├ form block        — margin:auto 0; width:100%; max-width:392px
  │   ├ brand + heading (centered: 44px mark, h1, subtitle)
  │   └ card (the fields)
  └ v1.0.0            — mono 11px --text-3, pinned to the bottom
```

`margin: auto 0` on the middle block is what centers it — the toggle and version stay pinned
top and bottom. Do not use `justify-content: center`; it would center all three children as a
group and pull the version up under the card.

At 392px this works unchanged on a phone; the only mobile change needed is dropping the page
padding to 16px.

### Type
| Element | Style |
|---|---|
| `MAKI POS Admin` | 21px / 600 / -0.55px |
| `Sign in to continue` | 13px `--text-2` |
| Field label | 11.5px / 600 `--text-2` |
| Input text | 13.5px |
| Button | 13.5px / 600 |
| Checkbox / links | 12–12.5px |
| `v1.0.0` | 11px mono `--text-3` |

### Card internals
Padding 22px, `gap: 15px`. Inputs: `--surface-2` fill, `1px --border`, radius 11px, padding
`11px 13px`. On focus the border goes `--accent-line`; when there is an error **both** borders
go `--neg` so the user sees which form failed, not which field.

Checkbox is a 17px rounded square — `--surface-2`/`--border` unchecked, `--accent` fill with
`--accent-line` border and an `--accent-ink` tick when checked. Not a native checkbox; the
native control can't be tokenized.

Password reveal is a 24px `IconButton` inside the field. Eye icon when hidden, eye-with-slash
when shown, with a matching `title`. Toggle `type` between `password` and `text`.

Error banner: `--neg-soft` fill, `1px --neg`, radius 11px, 12.5px `--neg` text with a circle
glyph, and a 0.3s `shake` on mount. Sits at the top of the card so it doesn't shift the
fields.

---

## 3. Behavior

- **Autofocus** the email field on mount.
- `Enter` in either field submits. Wrap the fields in a real `<form>` with
  `onSubmit={preventDefault + submit}` so browser password managers work — the reference uses
  a click handler only because it has no backend.
- `autocomplete="username"` and `autocomplete="current-password"` are required for password
  manager autofill.
- Button shows `Signing in…` at `opacity .65` and must be **disabled** while in flight; a
  double-submit is a duplicate auth attempt against the rate limiter.
- Clear the error on any keystroke in either field.
- Client-side validation is presence only. Never tell the user which of the two was wrong —
  one message for both: *That email and password don't match. Try again.*
- Theme persists to `localStorage['maki-pos-theme']`, same key as the rest of the app, so
  the choice survives into the dashboard.

---

## 4. Data wiring

```
POST /api/auth/login
{ email, password, remember: boolean }
→ 200 { token, refreshToken?, user: { id, name, email, role }, mustChangePassword: boolean }
→ 401 { error: 'invalid_credentials' }
→ 423 { error: 'locked', retryAfterSeconds }
→ 429 { error: 'rate_limited', retryAfterSeconds }
```

On success: store the token per your session strategy, then route by role — `ADMIN` to the
dashboard, cashier to POS. If `mustChangePassword`, route to a set-password screen instead.

`remember` controls session lifetime server-side (long-lived refresh token vs. session-only).
A shared shop terminal should default this **off**; the reference defaults it on because it
assumes the admin's own machine. Confirm with the client.

Error mapping — one user-visible message per class, never leaking which field failed:

| Response | Message |
|---|---|
| 401 | That email and password don't match. Try again. |
| 423 | Too many attempts. This account is locked for {n} minutes. |
| 429 | Too many attempts. Wait {n} seconds and try again. |
| network / 5xx | Can't reach the server. Check the connection and try again. |

Forgot password: `POST /api/auth/forgot-password { email }`. Always return 200 regardless of
whether the address exists — a differing response enumerates accounts. Not built.

### Security notes for whoever wires this
- Rate limit per email **and** per IP; lock after a threshold.
- Never log the password field, even at debug level.
- HTTPS only; set the session cookie `Secure`, `HttpOnly`, `SameSite=Lax` if using cookies.
- Log every attempt (success and failure) to Activity Logs with email, IP and timestamp.

---

## 5. Not built

Forgot-password request and reset screens · first-run set-password · 2FA · PIN-based quick
switch between cashiers on a shared register (worth asking about — it fits this shop's
workflow better than email + password at the counter) · account-locked screen.

---

## 6. Open questions

- Should `Keep me signed in` default on or off? Depends on whether registers are shared.
- Do cashiers sign in with email + password, or would a PIN pad suit the counter better?
- Is there a real password reset email pipeline, or does an admin reset it manually?

---

## 7. Definition of done

- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Real `<form>`, real labels tied by `for`/`id`, `autocomplete` present, `Enter` submits.
- Button disabled in flight; one generic error message for bad credentials.
- Keyboard: email autofocused, tab order email → password → reveal → checkbox → forgot →
  submit, focus rings visible.
