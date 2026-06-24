# MAKI POS — Design Handoff 02: POS · Checkout · Scanner

**Purpose.** A self-contained bundle representing the **current** UI of the POS sale flow, so you (or a
design session) can *see* what exists, then mark up what you want. Hand the marked-up version back and I'll
implement it in Flutter.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of the POS screen, Checkout screen,
  Barcode scanner, and the post-sale Success dialog. This is the visual.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, and a
  **"What I want" template** to fill in.

**Surface.** Flutter mobile app (`lib/`). Light theme shown; a dark theme exists (canvas `#0C1415`, gold
primary `#E8B84C`).

**Direction — note the shift.** These screens currently **inherit the new global theme we just shipped on
Login + Dashboard** (Figtree typeface, warm canvas, darkened slate `#283E46`, new input borders) — *but their
layout has not been restyled yet.* They still use the **pre-redesign structure**: flat hairline cards (no soft
shadows), **Cupertino icons** (not yet Lucide), and `lg`-radius buttons. So this bundle shows POS "as it renders
today," and the job is to bring it up to the new language: **soft-shadow elevation, the value/number as the hero,
Lucide icons, pill chips, and a clear primary action** — consistent with the Dashboard.

---

## Design system (the NEW tokens now in `lib/core/theme/`)

### Color (`app_colors.dart`)
| Token | Hex | Use |
|---|---|---|
| slate (primary) | `#283E46` | **light-theme primary** — filled buttons, selected chips, focus, links |
| gold (accent) | `#E8B84C` | accent; **dark-theme primary** |
| ink | `#121C1D` | brand ink · dark app-bar surface · text on gold |
| Light canvas / card | `#F6F5F3` / `#FFFFFF` | screen bg (behind cards) / elevated surface |
| Dark canvas / card | `#0C1415` / `#18262A` | screen bg / elevated surface (1px border `#243234`) |
| Input fill / border | `#FAFAFA` / `#E2E2E2` (light) · `#18262A` / `#2C3C3E` (dark) | fields |
| Text: primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` (light) · `#ECEFEF` / `#93A0A3` / `#6C797C` (dark) | text scale |
| success / cash | `#4CAF50` | chip: text `#2E7D32` on `#E8F5E9` (light) |
| gcash | `#007DFE` | chip: text `#024A99` on `#E3F0FF` (light) |
| warning / error | `#FF9800` / `#F44336` | discount-applied, insufficient-payment, void |

### Type — **Figtree** (Google Fonts), **Roboto Mono** for codes/SKUs/sale #
Hero value `38/700` (decimals smaller/muted) · section header `16/700` · stat value `18/700` · name/display
`16/600` · body `14–15/400–500` · label/caption `11–13/500–600` · chip/badge `10–11/600` uppercase ls .4 ·
mono code `12/600` ls .3.

### Spacing & radius (`app_spacing.dart`)
Spacing `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. Radius `field/button/chip 16 · list card 18 · hero 22 ·
avatar/tile 14 · pill 999`.

### Elevation (`app_shadows.dart`) — the defining change
Surfaces **lift with soft shadows** (light); dark uses a 1px border + a deeper shadow. `card`
`0 2px 8px rgba(17,28,29,.06)`; `hero` `0 10px 28px -10px rgba(17,28,29,.16)`; primary button
`0 8px 20px -6px rgba(40,62,70,.55)` (gold in dark). **POS still renders flat — this is the main upgrade.**

### Icons → **Lucide** (`lucide_icons`)
Login + Dashboard migrated to Lucide. **POS is still on Cupertino** — to migrate. Likely mapping:
search `search` · scan `scan-line`/`qr-code` · cart `shopping-cart` · trash `trash-2` · qty `minus`/`plus` ·
discount `tag` · labor/wrench `wrench` · mechanic `wrench`/`user` · edit `pencil` · proceed `arrow-right` ·
save-draft `save` · drafts `inbox` · back `chevron-left` · close `x` · success `check-circle` · receipt
`receipt` · warning `alert-triangle` · torch `flashlight` · flip-camera `switch-camera`.

---

## Screen 1 — POS  (`lib/presentation/mobile/screens/pos/pos_screen.dart`)

**Job:** search/scan products, build the cart, apply per-line discounts, optionally add mechanic labor, then
proceed to payment. Responsive: phones stack (search → cart); tablets (≥800px) split 3:2 (search left, cart right).

**App bar:** title **"Point of Sale"**; leading **back** (→ dashboard). Actions: **Drafts** (envelope + count
badge → `/drafts`) · **Clear Cart** (trash, only when cart non-empty → confirm dialog).

**Body, top → bottom (phone):**
1. **Product search** (`ProductSearchField`) — placeholder **"Search products or scan barcode…"**, prefix search
   icon, suffix **clear (×)** + **scan** (qr) → full-screen scanner. Results drop in an overlay (≤10 rows, max
   300px): each row = circular letter badge tinted by stock status (in/low/out = green/amber/red), product name
   (2 lines), `sku • ₱price`, trailing **"Stock: N"**; out-of-stock rows disabled. Empty = "No products found".
2. **Cart** — when empty: centered cart icon, **"Cart is empty"**, **"Search for products or scan barcode"**
   (muted). When filled, a scroll list of **`CartItemTile`** cards (swipe-right to delete, red trash bg):
   - Row 1: product name (2 lines) + compact **×** remove.
   - Row 2: `sku • ₱unitPrice/unit` (muted) + **CostCodePill** (compact cost sanity check).
   - Row 3 controls: **quantity stepper** (− N +, outlined 40px box; − disabled at 1) · **Discount** button
     (outlined; shows tag + "Discount", or `12%`/`₱50` in success-green when applied → opens
     `DiscountInputDialog`) · spacer · **line total** (right; if discounted, strikethrough gross above a
     green net).
3. **Labor & Service** (`ExpansionTile`, wrench) — subtitle **"Optional — add mechanic labor"** or
   **"N service(s) • ₱subtotal"**. Expands to: **MechanicPicker** dropdown (label "Mechanic", "— None —" +
   active mechanics) → **`LaborLineTile`** rows (wrench, description/"Service", fee, pencil-edit; swipe to
   delete) → optional labor error banner → **"Add labor line"** outlined button (opens add dialog: Description
   + Fee).
4. **`CartSummary`** — rows: **Items** "N (M products)" · **Subtotal** ₱… · **Discount** −₱… (green, if any) ·
   **Labor** ₱… (if any) · divider · **Total ₱…** — *the hero number* (titleLarge bold, primary).
5. **Fixed actions** (bottom, when non-empty): **"Proceed to Checkout"** (filled slate, arrow, 48px →
   `/checkout`) and **"Save as Draft"** (outlined, tray-down → name dialog "e.g., Table 5, Customer waiting").

**Components:** `ProductSearchField`, `CartItemTile`, `CartSummary`, `LaborLineTile`, `MechanicPicker`,
`DiscountInputDialog`, `CostCodePill`.
**States:** empty cart · search loading/empty/error overlay · processing · inline labor validation error.
**Role rules:** discount gated by **applyDiscount**; save-draft by **saveDraft**; entry by **accessPos**; labor
is open to all roles.

---

## Screen 2 — Checkout  (`lib/presentation/mobile/screens/pos/checkout_screen.dart`)

**Job:** confirm the order, choose a payment method, enter tender, see change/balance, then process the sale.

**App bar:** title **"Checkout"**; leading **back** (disabled while processing).

**Body (scroll), top → bottom:** uppercase section headers (`labelSmall`, ls .8, muted).
1. **ORDER ITEMS** — card list: each product row = **×N** quantity pill (outlined, primary) + name + sku
   (+ "12% off"/"-₱50" if discounted) + **₱net** right; each labor row = wrench badge + description + **₱fee**.
2. **PAYMENT SUMMARY** — card: **Subtotal/Parts subtotal** ₱… · **Discount** −₱… (green) · **Labor (N service)**
   ₱… (+ "Mechanic: name" muted) · divider · **Total ₱…** — *hero* (titleLarge bold primary).
3. **PAYMENT** (`PaymentSection`) — method selector = **ChoiceChips**: **Cash · GCash · Maya · Mixed · Salmon**.
   Then method-specific inputs:
   - **Cash / GCash / Maya:** **"Amount Received"** field (₱ prefix, **"Exact amount"** check-button fills the
     total, 2-dp) + quick chips **₱100 / ₱200 / ₱500 / ₱1000**. Cash also shows a **Change** box (green when
     sufficient, **"Amount Short"** red when not).
   - **Mixed:** segmented **GCash / Maya**, a digital-amount field, then **"Cash portion: ₱…"**.
   - **Salmon:** segmented **Cash / GCash / Maya**, a **Downpayment** field, then **"Salmon balance: ₱…"**
     (the receivable).
4. **Error banner** (if any) — error-bordered, exclamation + message.

**Fixed bottom button:** **"Confirm Payment • ₱{total}"** — full-width, **filled success-green**, check icon;
spinner while processing; disabled until the tender is valid.

**Components:** `PaymentSection` / `PaymentSelector`, `CheckoutSuccessDialog`.
**States:** processing (spinner, back disabled) · validation error banner · success (dialog) · pre-fills tender
from cart.
**Role rules:** **processSale** required (enforced upstream).

---

## Screen 3 — Barcode Scanner  (`lib/presentation/mobile/screens/pos/barcode_scanner_screen.dart`)

**Job:** full-screen camera to scan a barcode and return the value to the search field.

**App bar:** transparent, white foreground. Leading **× close**; title **"Scan Barcode"**; actions **torch**
(flash on/off) + **flip camera**.
**Body:** live camera (`MobileScanner`, fills screen) under an **IgnorePointer overlay**: a centered **240×240
white-bordered square (radius 16)** + **"Hold a barcode inside the box"** (white, shadowed). Single-shot: on
detect → haptic → pop the value.
**States:** permission denied ("Camera permission denied. Enable it in Settings to scan barcodes.") ·
unsupported · hardware error · scanning. **Icons are currently Material** here (`flash_on/off`,
`cameraswitch_outlined`).

---

## Screen 4 — Success dialog  (`checkout_success_dialog.dart`)

Post-sale modal (scale+fade in, haptic). Centered: **success check** (circled, green) → **"Payment
Successful!"** → **sale number** pill (mono) → **amount card** (Total / Received / **Change** highlighted big
green) → optional **Warnings** card (amber) → **"Receipt"** (outlined → `ReceiptWidget` bottom sheet) +
**"Done"** (filled green → back to POS). *Print is currently a stub.*

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name a screen, a region, and the change.

### Direction
- Bring POS fully into the new language (soft-shadow cards, Lucide, hero numbers)? Anything to keep flat? →
- Reference apps / vibes for a POS cart + checkout you like →
- What feels off today (density, tap targets, the cart row, the payment step) →

### POS screen — specific wants
- Cart row (`CartItemTile`): layout of name / qty stepper / discount / line total — what's the hero? →
- Quantity stepper + discount button treatment (size, color, where) →
- Cart summary: is **Total** the hero? Show it as a pinned bar? →
- Labor & Service: keep the expansion panel, or surface it differently? →
- Primary action: one **Checkout** button, or Checkout + Save-draft as shown? Placement (pinned bar)? →
- Empty-cart state →

### Checkout screen — specific wants
- Order-items + payment-summary cards (hierarchy, the Total) →
- **Payment method** picker: chips vs. a grid of tiles with brand icons (cash/gcash/maya/salmon)? →
- Tender entry: amount field + quick chips + the **Change** box treatment →
- Mixed / Salmon split UI →
- The **Confirm Payment • ₱total** button (keep green? full-width pinned?) →

### Scanner & Success dialog
- Scanner overlay framing / instructions / controls →
- Success dialog: hero (Change vs Total), buttons (Receipt/Done), warnings →

### Constraints / must-keep
- Role-gating (discount / save-draft / process-sale) must stay →
- All five payment methods + mixed/salmon split math must stay →
- Dark-theme parity →
- One-handed reach for the primary action (cashier speed) →

---

*Next screens queued (per the ~39-screen inventory): Inventory · Reports · Receiving · Expenses · Settings · … — one bundle at a time.*
