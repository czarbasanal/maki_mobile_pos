# MAKI POS — Design Handoff 03: Sale Detail

**Purpose.** A self-contained bundle showing the **current** UI of the Sale Detail screen so you (or a design
session) can *see* what exists, then mark up what you want changed. Hand the marked-up version back and I'll
implement it in Flutter.

**Note — this screen is already redesigned.** Unlike bundles 01/02 (which showed pre-redesign layouts to bring
*up* to the new language), Sale Detail was migrated in **bundle 03**: soft-shadow `AppCard` surfaces, the shared
`SummaryRow` (Total as a 26px hero), uppercase section headers, Lucide icons, and theme-aware colors — which
also **fixed a real dark-mode bug** (the screen was built from hardcoded `Colors.grey/red/amber` and rendered
broken on the dark canvas). So this bundle is for **refinement**: mark up anything you'd change now that it's
on-system.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of the redesigned Sale Detail in two
  states (a completed Salmon-split sale, and a voided sale with notes + labor). This is the visual.
- `README.md` (this file) — the design system, screen structure/copy/states/role rules, and a **"What I want"
  template** to fill in.

**Surface.** Flutter mobile app — `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`. Light shown;
dark theme has parity (canvas `#0C1415`, card `#18262A` + 1px hairline, gold primary, tints lifted to ~.18 alpha).

---

## Design system (tokens in `lib/core/theme/`)

### Color (`app_colors.dart`)
| Token | Hex | Use here |
|---|---|---|
| slate (primary) | `#283E46` | hero Total, sale total, links (light primary; gold in dark) |
| success | `#4CAF50` (text `#2E7D32` light / `#8FE39A` dark via `successText`) | Change value, "Completed" badge |
| error | `#F44336` | Voided banner/info tint, "Voided" badge, Void button |
| warning | `#FFC107` | Notes card tint + label |
| Light canvas / card | `#F6F5F3` / `#FFFFFF` | screen bg / `AppCard` surface |
| Dark canvas / card | `#0C1415` / `#18262A` | screen bg / `AppCard` surface (1px border `#243234`) |
| Text: primary / muted | `#16201F` / `#8A9296` | values / labels, dates, detail-row icons |

### Type — **Figtree**, **Roboto Mono** for sale # / SKU / cost code
Sale total hero `34/700` · **Payment Total hero `26/700` (-0.5 ls, primary)** · sale number `20/700` ·
section header `11/600` uppercase ls .8 muted · name/value `14/600` · row label/value `13` · badge `12/600`.

### Spacing & radius (`app_spacing.dart`)
Spacing `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. Radius `md 14 · field 16 · lg 18 (cards) · xl 24 (hero card) ·
pill 999 (status badge)`.

### Elevation (`app_shadows.dart`) & surfaces
Neutral cards = **`AppCard`** (light soft shadow `0 2px 8px rgba(17,28,29,.06)`; dark = 1px hairline border).
Tinted cards (Voided banner, Void info, Notes) are **theme-aware tinted `Container`s** (e.g.
`AppColors.error.withValues(alpha: .10 light / .18 dark)` + a .40 border), **not** `AppCard`.

### Icons → **Lucide** (`lucide_icons`)
`chevron-left` back · `file-text` receipt action + void reason · `user` cashier/voided-by · `wrench` mechanic/labor ·
`credit-card` payment method · `shopping-bag` items · `clock` voided-at · `sticky-note` notes · `x-circle` void.

---

## Screen — Sale Detail  (`sale_detail_screen.dart`)

**Job:** read-only record of one completed/voided sale — header total, line items, payment breakdown, metadata,
void affordance, and a receipt sheet.

**App bar:** title **"Sale Details"**; leading **back** (`chevron-left`); action **receipt** (`file-text` → opens
the existing `ReceiptWidget` bottom sheet — *unchanged, deliberately print-styled/monochrome*).

**Body, top → bottom:**
1. **Voided banner** *(voided only)* — error-tinted card: `x-circle` + **"VOIDED"** + void reason.
2. **Sale header** (`AppCard`, radius xl, centered) — **sale number** (`20/700`), **date · time** (muted),
   **₱ grand total** hero (`34/700`, slate; voided = muted + strikethrough), **status badge** (pill —
   success "Completed" / error "Voided").
3. **ITEMS** (`AppCard`, hairline-divided rows) — product row = **×N** slate qty badge + name + `sku · ₱unit` +
   `Code: XXX` (+ green discount line if any) + **₱net** right; labor row = gold `wrench` badge + description +
   "Labor" + **₱fee**.
4. **PAYMENT** (`AppCard`, `SummaryRow`s) — Subtotal · Discount (green −₱) · **Labor · {mechanic}** (folded) ·
   divider · **Total** hero (`26/700` primary) · divider · Received · **Change** (green) · then multi-tender rows
   when split (e.g. "Downpayment (GCash)", "Salmon balance").
5. **DETAILS** (`AppCard`, icon rows) — Cashier · Mechanic *(if any)* · Payment Method · Items "N (M products)" ·
   From Draft *(if any)*.
6. **Void Information** *(voided only)* — error-tinted card: Voided by · Voided at · Reason.
7. **Notes** *(if any)* — warning-tinted card: `sticky-note` + "Notes" + text.
8. **Void action** *(non-voided)* — **"Void This Sale"** (direct) or **"Request Void"** (request) — outlined,
   error-red; or a muted "Void pending approval" chip when a request is open.

**States:** completed · voided (banner + strikethrough + void-info) · multi-tender (Salmon/Mixed rows) · has-notes ·
void-pending · receipt sheet open.
**Role rules:** **voidSale** → direct void button; **requestVoidSale** → request button; neither → no affordance.

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the region and the change.

### Direction
- Overall: does the redesigned Sale Detail feel right, or anything off (density, hierarchy, the hero stack)? →
- Reference apps / receipts you like the look of →

### Sale header
- Is the **34px sale-total** the right hero, or should the **Payment → Total** be the only hero (avoid two big numbers)? →
- Status badge placement / style (pill vs text) →
- For voided: strikethrough total + red badge enough, or stronger treatment? →

### Items card
- Row density / what's the hero (name vs net) · qty badge + labor (gold wrench) badge treatment →
- Show per-item discount differently (strikethrough gross like the cart)? →

### Payment breakdown
- Order & grouping (Subtotal/Discount/Labor → Total → Received/Change → tenders) — regroup or add dividers? →
- **Change** emphasis (a tinted "Change" block like checkout, or the current green row)? →
- Multi-tender (Salmon/Mixed) rows — label format / indentation →

### Details / Void / Notes
- Details rows: icons + which fields, ordering →
- Voided banner & Void-info tint strength; Notes (amber) tint & label readability in light mode →
- Void button: outlined-red vs filled; placement (pinned bottom?) →

### Constraints / must-keep
- Read-only; receipt sheet stays the print-styled `ReceiptWidget` →
- Void role-gating (voidSale / requestVoidSale / pending) must stay →
- Multi-tender + Salmon downpayment math/labels must stay →
- Dark-theme parity →

---

*Bundles: 01-login-dashboard · 02-pos-checkout · 03-sale-detail (this). Queued next (per the screen inventory):
Inventory · Receiving · Reports · Settings · … — one bundle at a time.*
