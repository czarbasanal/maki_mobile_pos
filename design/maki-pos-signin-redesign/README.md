# MAKI MOTOR PARTS — Sign In Redesign Handoff

Everything Claude Code needs to build the redesigned sign-in screen.

## Read in this order

1. **Dashboard - Spec.md** — the skin. Fonts, type scale, both color palettes, geometry,
   theme rules, and the shared component library (§7). Start here; the guide assumes it.
2. **Sign In - Implementation Guide.md** — this screen: what changed and why, layout,
   card internals, behavior, auth endpoints and error mapping, security notes.

## Reference implementation

**Sign In.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it.

Interactive states to look at:
- **Default** — empty form on load.
- **Focus** — click a field; the border goes amber.
- **Error** — press `Sign in` with fields empty (validation), or fill both and submit to see
  the failed-credentials state after ~1s.
- **Password shown** — the eye button in the password field.
- **Dark** — the toggle at the top right; the choice persists to the same
  `localStorage['maki-pos-theme']` key the rest of the app uses.

Read exact values off the file; do not port the markup — rebuild from the component library.

## What this redesign fixes

The old screen was a bare form on pure white: no card, no brand, 770px-wide fields, and a
pure-black button that appeared nowhere else in the product. It is now a 392px card on the
app background with the amber brand mark, the standard amber primary button, plus the states
the original lacked — inline error, password reveal, keep-me-signed-in, loading label, and
the light/dark toggle. Copy is unchanged. Full rationale in §1 of the guide.

## Two things to get right

- **Use a real `<form>`.** The reference uses a click handler because it has no backend;
  ship a `<form onSubmit>` with `autocomplete="username"` / `"current-password"` or password
  managers won't autofill and `Enter` won't submit.
- **Disable the button while in flight** and show one generic error for bad credentials —
  never reveal which of the two fields was wrong.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- Should `Keep me signed in` default on or off? It depends on whether registers are shared
  machines; the reference defaults it on.
- Do cashiers sign in with email and password, or would a PIN pad suit the counter better?
- Is there a real password-reset email pipeline, or does an admin reset access manually?
