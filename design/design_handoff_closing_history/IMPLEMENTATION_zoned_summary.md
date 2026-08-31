# Closing History — expanded day summary · IMPLEMENTATION SPEC (Zoned summary)

**Target:** `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`
(+ `closing_widgets.dart`, `closing_handover_panel.dart`, `after_close_card.dart`, `variance_style.dart`)

**Design file:** `MAKI POS Closing History.dc.html` → option **1b · Zoned summary** (right-hand pair).
Open it in a browser; it ships light and dark. Option 1a in the same file is **not** the approved
direction — ignore it.

**Fidelity:** hi-fi. Colors, type, spacing, radii and copy below are final.

---

## ⛔ TWO HARD RULES

### Rule 1 — Follow the design faithfully

Recreate the zoned layout exactly, **light and dark**, with existing widgets and tokens
(`AppCard`, `app_colors`, `app_text_styles`, `app_shadows`, Lucide at stroke 1.75–2.2). Do not
improvise spacing, re-color, substitute icons, or reword labels. Where a Flutter equivalent exists,
reuse it — no parallel styling system.

### Rule 2 — Ask before wiring anything

This is a **restyle of a frozen document**. Everything is computed elsewhere and sealed into an
immutable closing. **Never change a figure, a formula, or the meaning of a row.** For any behavior,
data source, or computation not literally drawn here, **stop and ask the human** — see
*Open wiring questions* at the end. Two items in this spec are genuinely new and MUST be confirmed
before implementation: the **shop fees section** and the **After close "changed lines only"** rule.

### Invariants that must survive

1. Expansion stays **in place** (no detail route). Chevron flips.
2. **No row is dropped and no row is hidden at zero** in the sealed summary — `Plate No DP`,
   `Plate No Delivery`, `Labor (service)` render at `₱0.00`. (The After close block is the one
   exception; see § 5.)
3. Row order is fixed: **Sales → Shop fees → Expenses → Cash reconciliation → After close → Hand-over → byline.**
4. `Labor (service)` stays directly under gross parts, because the hand-over below subtracts labor.
5. Expected cash stays reconcilable on screen:
   `opening float + cash sales − cash expenses + plate DP − plate delivery`. Every term has a row.
6. Variance semantics unchanged (balanced / short / over) in both themes.
7. Colour stays scarce: variance chip, the after-close warning tone, the accent on the updated
   total. Nothing else is coloured.
8. **Mono (RobotoMono) money in the hand-over panel only** — plus the accent `Updated cash on hand`.
   Everywhere else uses Figtree with **tabular figures** (`fontFeatures: [FontFeature.tabularFigures()]`).

---

## 1 · Structure

The detail is an **inline block** under the tapped row, separated by a top hairline — not a card in
a card. Padding `12, 16, 14` (l/t/r-b as `EdgeInsets.fromLTRB(16, 12, 16, 14)`), children stacked
with **8px gaps**.

```
[ list row · unchanged ]
──────────────────────────── hairline
  ▢ SALES                 (recessed zone)
  ▢ SHOP FEES             (recessed zone)
  ▢ EXPENSES              (recessed zone)
  ▢ CASH RECONCILIATION   (recessed zone)
  ▢ After close           (raised card, amber-toned)   ← only when the day drifted
  ▢ CASH HAND-OVER        (raised card)                 ← always
  · Closed by <name> · <date> · <time>
  · Notes: <text>                                       ← only if notes were written
```

### The zone pattern (the whole idea)

Every group is a **recessed zone** whose heading sits inside it, and every zone **ends with the one
line it resolves to**, set above a hairline as the zone's result. Scanning vertically gives four
numbers — cash sales, shop fees, cash expenses, counted cash — before any detail is read.

```
┌ recessed, radius 14, padding 11/12 ────────────┐
│ ⌄ icon  HEADING                                │  10px / 700 / .7px tracking / muted
│    reference row              ₱0,000.00        │  12.5 muted label · 13 / 500 value
│      indented sub-row         ₱0,000.00        │  14px indent, dimmer label + value
│ ──────────────────────────── hairline          │  margin-top 8, padding-top 8
│    RESULT LINE                ₱0,000.00        │  13 / 600 ink · 14.5 / 700 ink
└────────────────────────────────────────────────┘
```

---

## 2 · Signs — every line that moves cash on hand carries one

`+` if the line **adds** to cash on hand, `−` if it **deducts**. Lines that are not cash-on-hand
terms carry **no** sign.

| Row | Sign | Why |
|---|---|---|
| Cash sales (Sales result) | `+` | adds |
| Opening float | `+` | adds |
| Plate No DP | `+` | adds |
| Cash expenses (Expenses result) | `−` | deducts |
| Plate No Delivery | `−` | deducts |
| Gross sales (parts), Labor (service), Non-cash sales + its sub-rows, Shop fees + its sub-rows, Total expenses | none | reference figures, not cash-on-hand terms |
| Expected cash, Counted cash | none | results, not terms |
| Everything inside **After close** that represents movement after closing | `+` | see § 5 |

Use the **minus sign `−` (U+2212)**, not a hyphen. Format stays `₱1,430.00`, grouped, two decimals;
sign precedes the peso symbol: `+₱8,335.00`, `−₱2,844.00`.

---

## 3 · The four zones (exact rows, in order)

### SALES — icon `arrow-down-left`
| Row | Treatment |
|---|---|
| Gross sales (parts) | reference |
| Labor (service) | reference — **renders at ₱0.00** |
| Non-cash sales | reference |
| ↳ GCash | indented, only if `> 0` |
| ↳ Maya | indented, only if `> 0` |
| ↳ Salmon receivable | indented, only if `> 0` |
| **Cash sales** | **result**, `+` |

### SHOP FEES — icon `receipt`  ← NEW SECTION, confirm before wiring
Third revenue track, alongside parts and labor; never added into gross.
| Row | Treatment |
|---|---|
| ‹fee type› (e.g. Shop supplies) | reference, one row per fee type |
| ‹fee type› (e.g. Disposal fee) | reference |
| **Shop fees** | **result** (the total), no sign |

Shop fees are cash that stays in the drawer: they reach **To management** with the rest of the
counted cash — **no hand-over line of their own**. If a day has no fee types, still render the zone
with the `Shop fees ₱0.00` result (invariant 2).

### EXPENSES — icon `arrow-up-right`
| Row | Treatment |
|---|---|
| Total expenses | reference |
| **Cash expenses** | **result**, `−` |

### CASH RECONCILIATION — icon `scale`
| Row | Treatment |
|---|---|
| Opening float | reference, `+` |
| Plate No DP | reference, `+` — renders at ₱0.00 |
| Plate No Delivery | reference, `−` — renders at ₱0.00 |
| Expected cash | reference |
| **Counted cash** | **result** — value preceded by the **variance chip** on the same line |

The variance chip inside the result line is compact: `radius 999`, padding `3/8`, `11.5px/700`,
11px glyph at stroke 2.6, **word only** (`Balanced` / `Short` / `Over`) — the signed amount stays on
the collapsed row's pill, which is unchanged. Chip and amount sit in a `Row` with `8px` gap.

---

## 4 · Cash hand-over panel (always)

A **raised card**, not a recessed zone — it is the block's conclusion.

```
▣ ⌄ CASH HAND-OVER                              eyebrow 10.5 / 700 / 1.1px tracking, icon banknote-arrow-up
  Dividing ₱5,491.00 from counted cash          caption 12, hint colour; amount in mono
  To mechanics                      ₱800.00     14 / 600 ink   ·   mono 15 / 700 ink
      Jeric                         ₱500.00     12.5, indent 14, dimmer   ·   mono 12.5 / 500
      Rico                          ₱300.00
  ──────────────────────────── hairline
  To management                   ₱4,691.00     14 / 600 ink   ·   mono 15 / 700 ink
```

- `To mechanics` = the day's whole labor revenue. Mechanics are settled **in cash from the drawer
  even when the customer paid labor digitally** — deliberate, do not "fix".
- `To management` = counted cash − labor. Opening float is **not** held back.
- **The duplicate `Counted` row is gone.** The old panel repeated counted cash as its first row;
  here the carry-forward is stated in the caption instead — the figure still appears once, as the
  reconciliation zone's result directly above.
- Per-mechanic lines are read from live sales while the total is frozen at closing, so they can
  disagree after a post-close void. When they do, render the existing muted note — do **not**
  silently substitute either figure.

### Drifted variant
- Caption becomes: **"Superseding the sealed count of ₱2,260.00 — see After close"**.
- `To mechanics` = whole-day labor; `To management` recomputed.
- A footer row closes the panel above a hairline:
  **`Updated cash on hand`** (13.5/600) · mono **16/700 in the accent colour** (slate light / gold dark).
- With drift the two destinations add to the **footer**, not to any figure above it
  (`550 + 4,720 = 5,270`).

---

## 5 · After close card (only when the day drifted)

Renders **above** the hand-over: what changed is explained before the hand-over states amounts that
moved. Raised card, amber-toned 1px border, `clock-alert` icon, title **"After close"** (14.5/700).

**Row rule (NEW — confirm before wiring):** the block spans **every frozen line** — sales, labor
fees, shop fees, expenses — but **renders only the lines that actually moved after closing**. A line
that did not change is omitted here entirely. This is the one place where lines are conditional; the
sealed summary above still shows everything, including ₱0.00. State it in the card:

> *Only the frozen lines that moved after closing are listed. Expenses did not change.*
> (11.5px, hint colour, directly under the title; name the unchanged lines.)

For each moved line the card gives **at closing → after closing → updated**, in three groups:

```
┌ recessed inner block, radius 11, padding 8/10 ────────┐
│  Total sales at closing            ₱1,740.00          │  frozen figures, 12.5 muted / dimmer value
│  Labor fees at closing               ₱400.00          │
│  Shop fees at closing                ₱120.00          │
│  Sales after closing         +3 · +₱2,800.00          │  movement, value 12.5 / 600 ink
│  Labor fees after closing            +₱150.00         │
│  Shop fees after closing              +₱60.00         │
│  Cash collected after closing      +₱3,010.00         │
└───────────────────────────────────────────────────────┘
   Updated sales                     ₱4,540.00           13 / 600 ink · 14.5 / 700 ink
   Updated labor fees                  ₱550.00
   Updated shop fees                   ₱180.00
   ──────────────────────────── hairline
   Updated cash on hand              ₱5,270.00           13.5 / 600 · mono 16 / 700 accent
```

- `Sales after closing` keeps its **count prefix**: `+3 · +₱2,800.00`.
- Everything in the movement group carries `+`.
- `Updated <line>` = at-closing + after-closing, and is **not** signed.
- `Updated cash on hand` = counted cash + cash collected after closing. It appears here as the
  result of the drift math and again as the hand-over footer (sum of the two destinations) — both
  are intentional and must match.

---

## 6 · Tokens

| Role | Light | Dark |
|---|---|---|
| Canvas | `#FFFFFF` | `#0C1415` |
| Card / list row | `#FFFFFF` + `0 2px 8px rgba(17,28,29,.06), 0 1px 1px rgba(17,28,29,.05)` | `#18262A` + 1px `#243234` |
| **Recessed zone** | `#FAFAFA` | `#152125` |
| Raised panel inside detail | `#FFFFFF`, 1px `#E4E4E4`, `0 2px 8px rgba(17,28,29,.05)` | `#1B2C31`, 1px `#2C3C3E` |
| After close border / icon | `rgba(245,124,0,.34)` / `#F57C00` | `rgba(245,181,71,.34)` / `#F5B547` |
| Ink | `#16201F` | `#ECEFEF` |
| Reference label | `#6E787B` | `#93A0A3` |
| Reference value | `#3C4749` | `#D6DDDE` |
| Indented label / value | `#9AA2A4` / `#5A6468` | `#6C797C` / `#AEC0C6` |
| Hairline (detail / inside zone) | `#ECECEC` / `#EDEDED` | `#243234` / `#223032` |
| Accent (updated total) | slate `#283E46` | gold `#E8B84C` |
| Variance · Balanced | `#2E7D32` on `#E8F5E9` | `#8FE39A` on `rgba(76,175,80,.16)` |
| Variance · Short | `#F44336` on `rgba(244,67,54,.10)` | `#FF6B5E` on `rgba(255,107,94,.14)` |
| Variance · Over | `#F57C00` on `rgba(245,124,0,.12)` | `#F5B547` on `rgba(245,181,71,.14)` |

**Radii** — list row / `AppRadius.field` 16 · zone, panel, after-close 14 · after-close inner block
11 · chips & pills full.

**Type (Figtree unless noted)** — zone heading 10/700/.7px tracking · reference label 12.5/400 ·
reference value 13/500 · indented 12.5 · zone result label 13/600, value 14.5/700 · hand-over
eyebrow 10.5/700/1.1px · hand-over caption 12 · destination 14/600 + **mono** 15/700 · per-mechanic
12.5 + **mono** 12.5/500 · updated cash on hand 13.5/600 + **mono** 16/700 · after-close title
14.5/700 · after-close note 11.5 · byline 11.5.

**Icons (Lucide)** — `arrow-down-left` (sales) · `receipt` (shop fees) · `arrow-up-right` (expenses) ·
`scale` (reconciliation) · `banknote-arrow-up` (hand-over) · `clock-alert` (after close) ·
`check` / `trending-up` / `trending-down` (variance) · `user` (byline) · `chevron-up/down` ·
`history` (empty state). Zone heading glyphs are 13px at stroke 2.2.

**Row rhythm** — reference rows `padding: 3px 0`; indented rows `3px 0 3px 14px`; after-close inner
rows `2.5px 0`; updated rows `3px 0`. Zone result: `border-top` + `margin-top 8` + `padding-top 8`.

---

## 7 · Unchanged surfaces

- **List row** (date `EEE, MMM d, y` 14/700 · two-line muted sub-line where only the amount is inked
  and semibold · variance pill with the **signed amount** · chevron) — untouched.
- **Loading** `ListSkeleton` · **error** `ErrorStateView` with Retry · **empty** `EmptyStateView`
  (history icon, "No closings yet" / "Closed days will show up here.").
- Byline `Closed by <name> · <date> · <time>` with `user` glyph; `Notes: <text>` only when written.

## 8 · Figures in the design file

Illustrative but internally consistent — the arithmetic closes in all four frames and is there so
you can verify your wiring, not to be shipped:

- **Ordinary day (light):** parts 7,960 + labor 800 + shop fees 260 (150 + 110) = 9,020;
  non-cash 685 (GCash 400, Maya 285) → cash sales **+8,335**; cash expenses **−2,844**; float, DP,
  delivery 0 → expected **5,491** = counted **5,491**, balanced. Hand-over: mechanics 800
  (Jeric 500, Rico 300), management **4,691**.
- **Drifted day (dark):** parts 1,740 + labor 400 + shop fees 120 (70 + 50) → cash sales **+2,260**,
  expected = counted **2,260**, balanced. After close: sales +2,800 (3 sales), labor +150, shop fees
  +60, cash collected **+3,010** → updated sales 4,540, updated labor 550, updated shop fees 180,
  **updated cash on hand 5,270**. Hand-over: mechanics 550 (Jeric 400, Rico 150), management 4,720;
  550 + 4,720 = 5,270.

---

## 9 · Open wiring questions — ASK BEFORE IMPLEMENTING

1. **Shop fees.** Which field(s) on the closing document hold them, and what are the real fee types?
   Are they already inside `cashSales`/`expectedCash` (the design assumes **yes** — they are drawer
   cash reaching management), or a separate track that must be added? Confirm the section is not
   double-counting.
2. **After close "changed lines only."** What is the comparison source for "did this line move" —
   the sealed document field vs the live recomputed value? Confirm the tolerance (exact inequality?)
   and confirm the copy that names the unchanged lines is generated, not hardcoded.
3. **Shop fees after closing.** Does the post-close delta expose shop fees separately from
   `Sale items` / `Labor fees` today, or does that need a new computation?
4. **Updated cash on hand** appearing twice (after-close result + hand-over footer) — confirm both
   read the same value from the same source.
5. **Variance chip in the reconciliation result line** — reuse `VarianceStyle` verbatim; confirm the
   word-only variant is acceptable given the collapsed pill already shows the signed amount.
6. **Salmon receivable / GCash / Maya** `> 0` conditions — unchanged, confirm the predicate.
7. Anything that reads or writes Firestore. Nothing in this spec should.
