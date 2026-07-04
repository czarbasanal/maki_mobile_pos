# MAKI POS — Design Handoff · READ THIS FIRST

**This repo holds the _approved visual redesign_ for MAKI POS. If you are Claude Code
implementing these screens in the app, the two rules below are non-negotiable.
Read this whole file before you touch a single widget.**

---

## 📁 What's in here

| File pattern | What it is |
|---|---|
| `MAKI POS <Feature>.dc.html` | The **approved redesign** for that feature — light **and** dark. This is the source of truth for look & feel. |
| `design_handoff_<feature>/README.md` | Documents the **current (pre-redesign)** implementation: exact Dart file paths, routes, Riverpod providers, data model, permissions, known bugs. Use it to find the real code to change. |
| `design_handoff_<feature>/reference_current-ui.html` | The old UI, for before/after comparison only. Do **not** reimplement this. |
| `MAKI POS Theme.dc.html` | The global elevated theme (tokens, light + dark, Login + Dashboard). The single reference for colors, type, elevation, icons. |

The `.dc.html` files are **design references written in HTML** — prototypes of intended
look and behavior. **Do not ship the HTML.** Recreate each design in the existing Flutter
codebase using its established widgets (`AppCard`, `AppDialog`, `EmptyStateView`,
`app_colors` / `app_text_styles` / `app_shadows`, etc.). Where a Flutter equivalent already
exists, reuse it — don't fork a parallel styling system.

---

## ⛔ RULE 1 — Follow the designs faithfully. Do not improvise.

Match the mocks **pixel-for-pixel**. Do not "improve," re-flow, re-color, or substitute
components, icons, or copy. If you think something should change, that's a **Rule 2 question** —
ask, don't act.

Hold these exactly:

- **Color** — slate `#283E46` primary (light); **gold `#E8B84C` leads in dark**; canvas
  `#F6F5F3` / `#0C1415`; ink text `#16201F` / `#ECEFEF`. Full **light + dark parity** on every
  screen — shipping only one theme is a failure.
- **Neutral-by-default discipline** — job orders / drafts have no status, so **do not invent
  status colors**. Color is reserved for: the slate/gold primary affordances (total · qty badge ·
  service badge · Open / Bill out), **green only** for a discount, **red only** for destructive
  (delete). Nothing else gets color.
- **Type** — Figtree for UI; **Roboto Mono** for SKUs, IDs, and codes. Keep the weights/sizes
  shown.
- **Icons** — **Lucide**, stroke width **1.75**. Do not swap in Material/Cupertino glyphs.
- **Shape & elevation** — card radius 18 / inner 16 / 14; the soft "elevated" shadows from
  `MAKI POS Theme.dc.html`. Dark surfaces use a 1px border (`#243234`), not a shadow.
- **Currency** — grouped, two decimals: `₱1,430.00`.
- **Copy** — use the exact strings in the mock.

If a value isn't spelled out in a given mock, lift it from the nearest equivalent element in the
same file or a sibling `MAKI POS *.dc.html` — **do not make one up.**

---

## ⛔ RULE 2 — Ask before wiring anything. Do not guess.

These files specify **appearance only**. For **any** behavior, data, or logic that isn't
literally drawn in the mock, **stop and ask the human** before implementing. Do not silently
scaffold, assume, or invent wiring. Preserve all existing business logic and money math — change
the presentation layer only, unless explicitly told otherwise.

Ask before wiring things like:

- Provider / stream sources and invalidation (e.g. what feeds a list, a count, a badge).
- Navigation targets and back-stack behavior.
- Permission / role gating (who can see or do what).
- Money math, totals, discounts, tax — confirm you're reusing the existing entity computations.
- Multi-step flows (e.g. **bill-out**, checkout reconciliation, draft→sale conversion).
- Validation rules, empty/loading/error states not shown.
- Anything that reads or writes Firestore.

**Design decisions that need a wiring confirmation** (call these out to the human):

- **POS badge re-icon (Job Orders):** the redesign changes the POS toolbar badge to a
  `clipboard-list` icon meaning "open job-order count." The current code showed a shopping-cart
  glyph and had a stale-count bug (see `design_handoff_drafts` / Job Orders README). Confirm the
  badge should bind to the **live `activeDrafts` stream length**, not a cached one-shot count.

When in doubt: **ask.** A wrong guess on wiring is worse than a question.

---

## Workflow per screen

1. Open the matching `design_handoff_<feature>/README.md` → note the real Dart files, routes, and
   providers.
2. Open `MAKI POS <Feature>.dc.html` → that's the target look (light + dark).
3. Rebuild the UI in Flutter with existing components/tokens (Rule 1).
4. List every piece of behavior the screen needs and **ask the human** to confirm the wiring
   before hooking it up (Rule 2).
