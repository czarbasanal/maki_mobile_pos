# Handoff: MAKI POS — Reports (Sales History · Sales Report · Profit Report · Top Selling)

> **Claude Code: follow every detail in this layout.** Treat `MAKI POS Reports.dc.html` as the source of
> truth and reproduce it **exactly** — every color, hex value, font size, weight, padding, gap, radius, border,
> shadow, icon, and copy string below is intentional and already verified. Do not redesign, "improve", round
> values, substitute icons, or drop states. Where this README and the HTML ever disagree, the **HTML wins** —
> open it and read the inline styles. Match it pixel-for-pixel in both **light and dark** themes.

## Overview
Bundle **06a** of the MAKI POS redesign — the **Reports family**: **Sales History** (list), **Sales Report**
(dashboard), **Profit Report** (restyled shell), and **Top Selling** (drill-down). It brings all four surfaces
onto the **elevated global theme** (bundles 01–05): flat Material `Card` elevation is replaced by soft-shadow
**`AppCard`** surfaces, **Cupertino icons → Lucide**, and the existing color discipline + dark-hairline parity
are kept. Slate is the primary in light; **gold leads in dark**. Light and dark are both fully specified.

This reuses the **global theme** — do **not** invent new tokens. Pull from `lib/core/theme/` (or the project's
established theme layer) exactly as bundles 01–05 did.

## About the Design Files
These files are **design references created in HTML** — a prototype of the intended look and behavior, **not
production code to ship**. The task is to **recreate them in the existing Flutter codebase**
(`lib/presentation/mobile/screens/reports/…` + `lib/presentation/mobile/widgets/reports/…`) using its established
widgets and the shared `AppCard` + theme layer. Translate the CSS values below into Flutter `ThemeData` / widget
styles. (If the target is some other environment, recreate faithfully using that stack's idioms — but the visual
result must be identical.)

- `MAKI POS Reports.dc.html` — the redesign prototype (all 4 screens, light + dark, + 2 role-state frames). **Source of truth.**
- `reference_current-ui.html` — the current pre-redesign UI (Cupertino + flat Material cards), for before/after only.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, and icons are final. **Match them precisely.**

---

## Source files (what to migrate)
| Screen | File |
|---|---|
| Sales History | `lib/presentation/mobile/screens/reports/sales_list_screen.dart` |
| Sales Report | `lib/presentation/mobile/screens/reports/sales_report_screen.dart` |
| Profit Report | `lib/presentation/mobile/screens/reports/profit_report_screen.dart` |
| Top Selling | `lib/presentation/mobile/screens/reports/top_selling_screen.dart` |
| Shared widgets | `…/widgets/reports/date_range_picker.dart`, `sales_summary_card.dart`, `top_products_card.dart` |

Container surfaces migrate from Material `Card` → `lib/presentation/shared/widgets/common/app_card.dart`
(`AppCard`): light = soft shadow; dark = `darkCard` `#18262A` + 1px hairline `#243234`.

---

## Design Tokens

| Token | Light | Dark |
|---|---|---|
| Screen canvas (behind cards) | `#F6F5F3` | `#0C1415` |
| Card / elevated surface (`AppCard`) | `#FFFFFF` + shadow | `#18262A` + 1px border `#243234` (no shadow) |
| Card shadow | `0 2px 8px rgba(17,28,29,.06)` | — (use the 1px hairline instead) |
| Row divider (inside a card) | `#F0F0F0` | `#243234` |
| Hairline / outline (metric & rank borders) | `#ECECEC` | `#243234` (rank-4+ ring `#2C3C3E`) |
| Primary (slate) | `#283E46` | gold `#E8B84C` **leads** |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| Success / profit | text `#2E7D32` on `#E8F5E9`, border/icon `#4CAF50` | text `#8FE39A` on `rgba(76,175,80,.16)`, icon `#5FC86A` |
| Error / void | `#F44336` | `#FF6B5E` |
| Warning (daily-only banner) | bg `#FFF6E6`, border `#F0C36B`, icon `#C8881A`, title `#8A5E12`, sub `#A07A2E` | bg `rgba(245,181,71,.12)`, border `rgba(245,181,71,.4)`, text `#F5B547` |
| Info accent (legend only) | `#2196F3` | — |

**Payment methods** (icon · text-on-fill):
| Method | Icon | Light | Dark |
|---|---|---|---|
| Cash | `banknote` | `#2E7D32` on `#E8F5E9` | `#8FE39A` on `rgba(76,175,80,.16)` |
| GCash | `smartphone` | `#024A99` on `#E3F0FF` | `#7FB6FF` on `rgba(0,125,254,.2)` |
| Maya | `wallet` | `#283E46` on `rgba(40,62,70,.07)` | `#B8C4C4` on `rgba(255,255,255,.07)` |
| Mixed | `layers` | `#5A6468` on `rgba(40,62,70,.06)` | `#9FB0B0` on `rgba(255,255,255,.06)` |
| Salmon | `fish` | `#5A6468` on `rgba(40,62,70,.06)` | `#B8C4C4` on `rgba(255,255,255,.07)` |

**Payment-breakdown bar fills** (Sales Report): Cash `#4CAF50`/`#5FC86A` · GCash `#007DFE`/`#5AA9F0` ·
Maya `#283E46`/`#9FB0B0`. Track `#ECECEC`/`#243234`, height 7, radius 999.

**Rank medals — the kept amber/silver/bronze idiom** (medal = 28px circle, 1.5px ring, 12/700 number; bar = 6px, radius 999, track `#ECECEC`/`#243234`):
| Rank | Ring | Number (light/dark) | Bar fill (light/dark) |
|---|---|---|---|
| 1 | `#E8B84C` | `#B07A12` / `#E8B84C` | `#E8B84C` / `#E8B84C` |
| 2 | `#90A4AE` | `#5E7079` / `#AEC0C6` | `#90A4AE` / `#90A4AE` |
| 3 | `#B08D6F` | `#8A6244` / `#CBA890` | `#B08D6F` / `#B08D6F` |
| 4+ | `#ECECEC` / `#2C3C3E` | `#8A9296` / `#93A0A3` | `#283E46` / `#5E7A84` |

**Net Sales panel:** bg `rgba(40,62,70,.06)` (light) / `rgba(232,184,76,.10)` (dark), radius 13, padding 13×15;
label 14/600 ink; value **20/700, letter-spacing −.3**, slate (light) / **gold (dark)**.

**Profit badge (admin, on Top Selling rows):** `+₱5,160`, 11/700, success text on success-tint (see Success row),
radius 7, padding 2×7.

**Type:** **Figtree** (400/500/600/700/800) primary; **Roboto Mono** (500/600) for **sale numbers** (`SALE-…`) and
**SKUs** (`ngk-014`). Sizes in use: app-bar title 18/600 · card title 15/700 · day total 16/700 · Net Sales 20/700
· metric value 15–18/700 · body 13–14 · labels 11–12/500 · pill/badge 10–11 · VOID badge 9. Currency renders
grouped (`₱1,234.00`) from the app-wide formatter. Uppercase mini-labels use letter-spacing .5–.8.

**Radii:** metric/date-control 13–14 · sale leading square 11 · list & summary cards 18 · EOD tile 16 · pills /
medals / bars 999. (Device bezel `42` in the mock is **not** part of the app.)

**Icons — Lucide, stroke 1.75** (1.85 for small inline, 1.9–2 for emphasis):
status `signal-high`/`wifi`/`battery-full` · back `chevron-left` · reports `bar-chart-3` · preset `calendar-days` ·
range `calendar` · expand `chevron-down` · sale `file-text` · voided `x-circle` · top-selling `star` ·
profit/trend `trending-up` · total-sales `file-text` · gross-sales `banknote` · discounts `tag` · total-cost
`package`/`wallet` · service `wrench` · average `divide` · margin `percent` · admin-gate / role-note `lock` ·
end-of-day `circle-dollar-sign` · chevron `chevron-right` · change-range `pencil` · daily-only warning
`alert-triangle`. Payment icons per the table above.

---

## Screens / Views

> Every screen is a flex **column**: status bar (36) → app bar (≈52) → **scrolling body**. Reports screens have
> **no pinned bottom bar** (unlike POS/Inventory). App bar + status bar sit directly on the **screen canvas**
> (`#F6F5F3`/`#0C1415`) — there is no separate white app-bar surface here.

### Shared — DateRangePicker  (`widgets/reports/date_range_picker.dart`)
A row of **two controls**, gap 8, padding `14 16 12`. Each is an `AppCard`-style pill (height 46, radius 14;
light `#FFFFFF` + card shadow; dark `#18262A` + border `#243234`).
- **Preset dropdown** (`flex:1`): `calendar-days` icon (slate / **gold** in dark) + label **14/600** (`white-space:nowrap`) + trailing `chevron-down` (muted). Opens the preset menu.
- **Active-range pill** (`flex:1.3`, so the date never clips): `calendar` icon + date label **13/500** (ellipsis) + `chevron-down`. **Tapping opens a custom date-range picker.**

**Default ranges (preserve):** Sales History = **Today** · Sales Report = **Today** · Top Selling = **This Month**
· Profit Report = **last 30 days** (flat strip, below). *The mock shows Sales Report / Top Selling populated at
"This Month / Jun 1 – 27, 2026" to illustrate a full dataset — the on-open default is still per this list.*

**Role gate:** for **daily-reports-only roles** the whole picker is **replaced** by the forced-today banner (see Role States); range is locked to today.

---

### Screen 1 — Sales History  (`sales_list_screen.dart`)
**Purpose:** browse past sales, grouped by day, filter by date.

**App bar:** `chevron-left` back · title **"Sales History"** (18/600) · trailing **Reports** action `bar-chart-3`.

**Body:** DateRangePicker, then **per-day groups**:
- **Day header** (on canvas, padding `4 18 8`, baseline-aligned): left = **day label 14/700** (e.g. "Today",
  "Thursday, June 26") + **"N sales" 12 muted** under it; right = **day total 16/700** in **slate (light) / gold
  (dark)**.
- **Day card** (`AppCard`, radius 18, padding `2 14`) holding that day's **sale rows**, each divided by the
  `#F0F0F0`/`#243234` hairline (last row no divider). **Sale row** = `display:flex; align-items:center; gap:12; padding:11 0`:
  - **Leading** 38×38 rounded-11 tinted square — normal: `rgba(40,62,70,.07)` (dark `rgba(255,255,255,.05)`) + `file-text` slate/`#9FB0B0`; **voided:** `rgba(244,67,54,.10)` (dark `rgba(244,67,54,.16)`) + `x-circle` error.
  - **Middle** (flex:1): **sale number** in **Roboto Mono 12.5/600** (`SALE-20260627-5`). If **voided**: muted + **strikethrough** + a `VOID` badge (9/600, error border + text, radius 5, padding 1×4). Sub line **12 muted**: `2:14 PM • Maria • 3 items` (`time • cashier • N items`).
  - **Trailing** (right-aligned): **grand total 15/700** (voided = muted + strikethrough), and **below it** a **payment pill** (10/600, icon + label, radius 999, padding 2×7) per the payment table.

**Mock data (reproduce verbatim):** **Today · 5 sales · ₱8,420.00** → `SALE-…627-5` 2:14 PM Maria 3 items ₱1,250.00 **Cash** · `…627-4` 1:02 PM Maria 1 item ₱340.00 **GCash** · `…627-3` **VOID** 11:48 AM Juan 2 items ₱980.00 **Maya** · `…627-2` 10:20 AM Juan 6 items ₱4,600.00 **Mixed**. **Thursday, June 26 · 11 sales · ₱22,180.00** → `…626-11` 6:30 PM Maria 4 items ₱2,100.00 **Cash** · `…626-10` 5:55 PM Maria 2 items ₱880.00 **Salmon**.

---

### Screen 2 — Sales Report  (`sales_report_screen.dart`)
**Purpose:** the reporting dashboard for a date range.

**App bar:** `chevron-left` back · title **"Sales Report"**.

**Body:** DateRangePicker, then four stacked `AppCard`s (margin 16, gap 12):

1. **Sales Summary** (`sales_summary_card.dart`) — header `bar-chart-3` (slate/**gold**) + **"Sales Summary" 15/700**. Then **outlined metric mini-cards** in 2-up rows (each: border 1px `#ECECEC`/`#243234`, radius 13, padding 11×12; label row = 15px icon + **11/500 muted label, `white-space:nowrap`**; value **15–17/700**; optional 10px sub):
   - Row: **Total Sales** `142` · **Voided** `3` *(error variant: border `#F44336`, icon+label+value error)*.
   - Row: **Gross Sales** `₱248,900.00` (sub "Before discounts") · **Discounts** `-₱4,120.00`.
   - **Net Sales panel** (see token) — `Net Sales` / **₱244,780.00**.
   - **— ADMIN ONLY —** divider: hairline + centered `lock` + uppercase 10/600 label, color hint (`#9AA0A3`/`#6C797C`). **Everything below is admin-only.**
   - **Average sale value** row: `divide` icon + label (muted) + **value 11.5/700 right** `₱1,723.80`.
   - Row: **Total Cost** `₱168,400.00` · **Gross Profit** `₱76,380.00` (success variant, sub "31.2% margin").
   - Row: **Service Rev.** `₱12,300.00` (sub "Labor · no COGS") · **Service Profit** `₱12,300.00` (success).

2. **Top Selling Products** (`top_products_card.dart`, **Top 10**) — header `star` + title + right tag **"Top 10" 11/600 muted**. Three **rank rows** (see Shared rank component below).

3. **Payment Methods** — header `wallet` + title. Three rows, each: label 13/600 + `**₱amount** · NN.N%` (muted, amount bold ink) on one baseline, then a **method-colored bar** (height 7) below. **Cash ₱132,400.00 · 54.1%** · **GCash ₱68,900.00 · 28.1%** · **Maya ₱43,480.00 · 17.8%**.

4. **End-of-Day Closing** tile (`AppCard`, radius 16, padding 14×16): 40×40 rounded-11 tinted square + `circle-dollar-sign` (slate / **gold** in dark, tint `rgba(232,184,76,.12)`) · title **"End-of-Day Closing" 14.5/600** + sub "Reconcile the cash drawer" 12 muted · trailing `chevron-right`.

**Shared rank row** (used here and on Top Selling): top line = **medal circle** (per rank table) + **product name 13.5/600** (ellipsis) over **SKU 11.5 mono muted** + right column **"N sold" 13.5/700** over **₱revenue 11.5 muted**. Second line, indented past the medal (28px spacer): **progress bar** (medal-colored, width = share of #1) + **admin profit badge** `+₱…` at the far right.

---

### Screen 3 — Profit Report  (`profit_report_screen.dart`)
**Purpose:** profit overview. **Restyle the shell only** — data wiring is out of scope, so values read `₱0.00` with an empty state.

**App bar:** `chevron-left` back · title **"Profit Report"** · trailing `calendar` (pick range).

**Body** (flex column so the empty state fills remaining height):
- **Flat date strip** (`AppCard`, height 48, radius 14, padding 0×14): `calendar` icon (slate/gold) + **range 13.5/500** `May 28 – Jun 27, 2026` (flex:1) + **"Change" button** — a small outlined pill (`pencil` + "Change", 12/600 primary, border `#D9DEDD`/`#2C3C3E`, radius 999, padding 5×11).
- **4 metric cards** (2×2, outlined like Sales Summary, on `#FFFFFF`/`#18262A`): **Total Revenue** `₱0.00` (`banknote`) · **Total Cost** `₱0.00` (`wallet`) · **Gross Profit** `₱0.00` (success, `trending-up`) · **Profit Margin** `0.0%` (success, `percent`). Values 18/700.
- **"Profit by Product"** section header (15/700) + **"View All"** link (13/600 primary, right).
- **Empty state** (centered, fills remaining space): 66px circle (`rgba(40,62,70,.06)`/`rgba(255,255,255,.05)`) holding `trending-up` (30px, hint color) · **"No profit data available" 15/700** · **"Make some sales to see profit reports" 13 hint**.

---

### Screen 4 — Top Selling  (`top_selling_screen.dart`)
**Purpose:** the full ranked drill-down, **capped at 20**.

**App bar:** `chevron-left` back · title **"Top Selling"**.

**Body:** DateRangePicker, then one **Top Selling Products** `AppCard` (header `star` + title + right tag **"Top 20"**) with **rank rows** (same shared component, **5 shown** in the mock; ranks 4–5 use the neutral medal + slate/`#5E7A84` bar):
1 **NGK Spark Plug CPR6EA-9** `ngk-014` · 86 sold · ₱17,200.00 · `+₱5,160` · bar 100%
2 **ASK Brake Shoe XRM 125** `ask-001` · 64 sold · ₱16,000.00 · `+₱4,480` · 74%
3 **Motul 10W-40 Engine Oil 1L** `mot-101` · 51 sold · ₱16,830.00 · `+₱3,570` · 59%
4 **Yamaha Drive Chain 428** `yam-228` · 37 sold · ₱11,100.00 · `+₱2,590` · 43%
5 **Bendix Brake Pad XRM** `ben-330` · 29 sold · ₱8,700.00 · `+₱2,030` · 34%

---

## Role gating & states  ⚠ must survive the restyle
These are the two behavioral rules to preserve, shown as dedicated frames (frames 5 & 6 in the HTML, light theme).

1. **Daily-reports-only role — Sales History.** The **DateRangePicker is replaced** by a **warning banner**
   (margin 16, radius 14, warning tokens): `alert-triangle` + **"Showing today's sales only" 13/600** + sub
   "Your role can view the current day's sales." Range is **forced to today** — only the **Today** group renders,
   followed by a muted footer `lock` + "Earlier days are not available for your role".

2. **Cashier / staff — Sales Report (cost & profit hidden).** Same layout as admin **minus everything admin-only**:
   the **Sales Summary stops at Net Sales** (no ADMIN-ONLY divider, no average, **no Total Cost / Gross Profit /
   Service** rows) and shows a muted `lock` note **"Cost & profit are hidden for your role"**; **Top Selling rows
   drop the green profit badge** (bar runs full width); Payment Methods stays. **Profit Report is not accessible
   to this role at all.** Cashiers/staff must **never** see cost or profit anywhere.

**Admin-only surfaces (gate exactly):** `Total Cost`, `Gross Profit` (+ margin), `Service Revenue` / `Service
Profit`, the **Average sale value** row, the **per-row profit badge** on Top Selling, and the whole **Profit
Report** screen.

---

## Interactions & Behavior
- **Date filtering** drives every screen: preset dropdown sets the range; the active-range pill opens a custom
  range; both re-query and re-render. Profit Report's "Change" opens the same custom-range picker.
- **Voided sales** render with the error leading glyph, strikethrough number + amount, and the `VOID` badge — but still appear in the list (and still count toward the per-day total per current logic).
- **Tap targets:** sale rows → Sale Detail (bundle 05); EOD tile → End-of-Day Closing; "View All" / Top-10 tag → Top Selling. Keep min 44px touch targets.
- **Theme toggle** swaps the entire light/dark token set (both columns of every table above) — including primary flipping slate → gold for day totals, Net Sales, card-head icons, date-picker icons, and rank-1.
- No new animations introduced; use the app's standard list/scroll behavior.

## State Management
Reuse the existing reports providers/blocs. Needed: selected date range + preset (per screen, with the defaults
above) · grouped sales (day → rows: number, time, cashier, item count, total, payment method, voided flag) · day
totals · summary aggregates (total/voided counts, gross, discounts, net, average; **admin:** total cost, gross
profit + margin, service revenue/profit) · payment-method breakdown (amount + %) · top-products list (rank, name,
SKU, qty, revenue, **admin:** profit) capped 10/20 · profit-report aggregates (currently zeroed) · **current role
+ its capability flags** (daily-reports-only, admin cost/profit visibility).

## Must-keep
- **Role gating** exactly as above (daily-only banner + forced today; admin-only cost/profit/service/average/badge; Profit Report admin-only).
- **Dark-theme parity** on every screen (gold leads).
- The **amber/silver/bronze rank-medal** idiom and **success-green / error-red** semantic accents.
- **Neutral-by-default** color discipline — color only for status/role meaning, never decoration.
- Grouped currency `₱1,234.00` via the app formatter; **SKUs and sale numbers in Roboto Mono**.
- DateRangePicker = preset dropdown + active-range pill; defaults per screen.
- `AppCard` everywhere a container surface exists (no leftover flat Material `Card` elevation).

## Assets
- Icons: **Lucide** (`lucide_icons`) — migrate Reports **off Cupertino**. No custom SVGs (the mock's sparkline-free; bars are plain `Container`s).
- Fonts: **Figtree** + **Roboto Mono** (already in the project).
- No images/photography in these screens.

## Files
- `MAKI POS Reports.dc.html` — redesign prototype, **source of truth** (4 screens × light/dark + 2 role-state frames).
- `reference_current-ui.html` — current/flat UI (Cupertino + Material `Card`), before/after only.
