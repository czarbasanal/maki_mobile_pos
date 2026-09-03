# MAKI MOTOR PARTS — Date Range Calendar Handoff

A shared date-range filter component. Belongs in `FilterBar` (spec §7) and is used by
Receiving, Job Orders, Reports, Expenses and Activity Logs.

## Read in this order

1. **Dashboard - Spec.md** — the skin: fonts, type scale, both color palettes, geometry,
   theme rules, shared component library. Start here; the guide assumes it.
2. **DateRangeCalendar - Implementation Guide.md** — this component: interaction rules,
   anatomy, the day-cell state table, implementation notes, and the component contract.

## Reference implementation

**DateRangeCalendar.dc.html** — opens directly in a browser (no build step) and needs
`support.js` beside it. The popover starts open so you can see it immediately.

Try these:
- **Click one day** → sets From; the footer hint changes.
- **Hover another day** → the provisional range paints as you move.
- **Click a second day** → sets To; `Apply` becomes fully opaque.
- **Click a day earlier than From** → the pair swaps instead of erroring.
- **Click again once both are set** → starts a new range.
- **Escape, or click outside** → closes. So does re-clicking the `Custom` pill.
- **Dark** — the toggle top right; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild it as the shared component.

## What this replaces

Two native `<input type="date">` fields side by side (`mm/dd/yyyy — mm/dd/yyyy`). That meant
two separate browser pickers for one range, unstyleable chrome that ignored every token in
both themes, and a format demand that invited invalid and backwards input. Now it is one
calendar: first click From, second click To.

## Four things to get right

- **Reversed selection swaps, it never errors.** A user who clicks the end of their range
  first meant what they clicked. Don't validate "To after From" — make it impossible to
  express.
- **Dates cross the wire as `YYYY-MM-DD` strings.** A client-side `toISOString()` shifts the
  date across midnight for anyone west of UTC and silently drops a day of results. Let the
  API interpret in `Asia/Manila`, and make `to` inclusive through 23:59:59.
- **Always render 42 cells.** Six weeks with adjacent-month days greyed, so the grid height
  never changes between months and the footer doesn't jump under the cursor.
- **Dropdown dismissal.** Close on Apply, outside `mousedown` and `Escape`, with both
  document listeners removed on unmount.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Known gap

No keyboard navigation yet — arrows to move within the grid, `Enter` to select. Until that
exists the control is mouse-only, which fails the app's own definition of done. Add it when
you build the shared version.

## Open questions for the client

- Week starts Sunday or Monday?
- Should `Apply` be explicit, or should the second click apply and close? Explicit is right
  for server-fetched tables; auto is friendlier for local filters. Pick one for the whole app.
- Any screen where a future date is legitimate? Otherwise `maxDate` should default to the
  business date everywhere.
