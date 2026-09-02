# MAKI MOTOR PARTS — Admin Overhaul Handoff

Everything Claude Code needs to build the new admin skin. Four screens are designed; the
rest of the app follows the same component library.

## Read in this order

1. **Dashboard - Spec.md** — the skin. Fonts, type scale, both color palettes, geometry,
   theme rules, dashboard data wiring, and the shared component library (§7).
   Start here; the other guides assume it.
2. **POS Register - Implementation Guide.md** — the register: catalog search, cart, labor,
   discounts, money math, checkout endpoints, keyboard map.
3. **Job Orders - Implementation Guide.md** — the job order list and sale detail: saved
   views, the custom dropdown filter, the table overflow pattern, both empty states, and
   the sale detail facts strip.

## Reference implementations

- **Dashboard.dc.html**
- **POS Register.dc.html**
- **Job Orders & Sale Detail.dc.html** — three views in one file:
  - **Job orders with rows** — the default state on load.
  - **Sale detail** — click any BILLED row, or its "View sale" button. "Back to job orders"
    returns.
  - **Job orders empty state** — the first-run state. In the reference it is behind a
    `showEmptyState` prop; to see it, set `showEmptyState: true` (or make `JOBS` an empty
    array in the logic class). In production the condition is `totalCount === 0` from the
    server, *not* `rows.length === 0` after filtering — filtered-to-nothing is a different,
    also-implemented state.

All three files open directly in a browser (no build step) and need `support.js` beside
them. Read exact values off them; do not port the markup — rebuild from the component
library in §7 of the spec.

Open each file at 1400px or wider — the layouts are designed for a desktop admin, and both
tables have inner horizontal scrollers below that.

## Order of work

Tokens → shared components → Dashboard → Inventory → POS → Job Orders → Receiving →
Suppliers → Expenses → Reports → Void Requests → Users → Activity Logs → HR → Settings.

## Three bugs the guides call out — do not re-introduce

- **Table overflow.** A card with `overflow:hidden` clips columns with no scrollbar. Every
  table needs an inner `overflow-x:auto` scroller plus a `min-width`. Bake it into
  `DataTable`.
- **Theme transitions.** Never put a CSS `transition` on `background` when the value comes
  from a `var()` — the old color gets pinned when the custom property flips.
- **Dropdown dismissal.** A custom select must close on outside `mousedown` and `Escape`,
  with both listeners removed on unmount.

## Open questions for the client

- Does the receipt carry VAT, and is it inclusive or added on top?
- May per-line and order-level discounts stack? Is labor discountable?
- Should `motorcycle` become a model list with a plate number field? It is free text today
  and the casing is inconsistent (`Smash`, `MioSporty`, `AIRBLADE`), which suggests hand
  entry. Both screens have room for a plate under the model without redesign.
