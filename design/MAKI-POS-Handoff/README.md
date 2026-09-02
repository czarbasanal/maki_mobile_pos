# MAKI MOTOR PARTS — Admin Overhaul Handoff

Everything Claude Code needs to build the new admin skin.

## Read in this order

1. **MAKI POS Dashboard - Spec.md** — the skin. Fonts, type scale, both color palettes,
   geometry, theme rules, dashboard data wiring, and the shared component library (§7).
   Start here; every other file assumes it.
2. **POS Register - Implementation Guide.md** — the POS screen. Layout constraints,
   component specs, money math, endpoints, keyboard map.

## Reference implementations

- **MAKI POS Dashboard.dc.html** — the dashboard, light + dark.
- **POS Register.dc.html** — the POS register, light + dark.

Both open directly in a browser (no build step) and need `support.js` sitting beside them.
Use them to read exact values; do not port the markup — rebuild from the component library.

## Order of work

Tokens → shared components → Dashboard → Inventory → POS → Job Orders → Receiving →
Suppliers → Expenses → Reports → Void Requests → Users → Activity Logs → HR → Settings.

## Open questions for the client

- Does the receipt carry VAT, and is it inclusive or added on top?
- May per-line and order-level discounts stack?
- Is labor discountable?
