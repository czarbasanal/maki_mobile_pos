# MAKI POS — Design Handoff 01: Login & Dashboard

**Purpose.** A self-contained bundle representing the **current** UI of two mobile screens, so you (or a
design session) can *see* what exists, then mark up what you want. Hand the marked-up version back and I'll
implement it screen-by-screen in Flutter.

**What's in here**
- `current-ui.html` — open in any browser: a faithful, token-accurate reconstruction of both screens side by side. This is the visual.
- `README.md` (this file) — the design system, per-screen structure/copy/states, and a **"What I want" template** to fill in.

**Surface.** Flutter mobile app (`lib/`). Light theme shown; a dark theme exists (bg `#121C1D`, gold accent `#E8B84C`).
**Established direction (current):** airy / minimal — neutral by default, **color only for status & role**, flat
surfaces with hairline borders (no shadows), generous rounding. The value/number is the hero, not the icon.

---

## Design system (exact tokens — `lib/core/theme/`)

### Color (`app_colors.dart`)
| Token | Hex | Use |
|---|---|---|
| primaryDark | `#121C1D` | brand ink · dark-theme bg |
| brandSlate | `#334E58` | **light-theme primary** — filled buttons, focus, primary pill |
| primaryAccent | `#E8B84C` | gold — dark-theme accent only |
| lightBackground | `#FFFFFF` | screen bg |
| lightSurface / surfaceMuted | `#F5F5F5` / `#FAFAFA` | quiet panels, inputs |
| lightHairline | `#ECECEC` | outlined cards / quiet separators |
| lightBorder | `#D0D0D0` | input borders |
| lightText / secondary / hint | `#000000` / `#666666` / `#999999` | text scale |
| success / warning / error / info | `#4CAF50` / `#FFC107` / `#F44336` / `#2196F3` | status (each has light+dark variants) |
| cash / gcash / draft / voided | `#4CAF50` / `#007DFE` / `#FF9800` / `#9E9E9E` | POS status |
| role: admin / staff / cashier | `#9C27B0` / `#2196F3` / `#4CAF50` | role badges |

### Type (`app_text_styles.dart`) — Roboto; monospace for codes/SKUs
`headingXL 32/700` · `headingLarge 28/700` · `headingMedium 24/600` · `headingSmall 20/600` ·
`bodyLarge 18` · `bodyMedium 16` · `bodySmall 14` · `labelLarge 16/600` · `labelMedium 14/500` ·
`labelSmall 12/500` · `priceXL 36/700` · `priceLarge 24/700` · `badge 11/600` · `code` & `costCode` (mono).

### Spacing & radius (`app_spacing.dart`)
Spacing `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`. Radius `sm 10 · md 14 · lg 18 · xl 24 · pill 999`
(mobile leans on `lg`/`xl`; `pill` for chips/segmented controls).

---

## Screen 1 — Login  (`lib/presentation/shared/screens/auth/login_screen.dart`)

**Job:** sign a user in. Single centered column, `maxWidth 360`, white bg.

**Structure (top → bottom):** app icon (64×64, radius 14) → `MAKI POS` (18/700, letter-spacing **2.4**, ink
`#121C1D`) → `Sign in to your account` (14, secondary) → [error banner, conditional] → Email field → Password
field → **Sign in** (full-width, filled `brandSlate`) → `Forgot password?` (13, secondary text button) → `v1.0.0`
(11, hint).

**Components:** `AppTextField` (outlined, floating label, `radius md`), `AppButton` (filled brand slate),
`LoadingOverlay` ("Signing in…").
**States:** default · loading (overlay) · field validation errors · auth-error banner (`errorLight` bg, error
icon, `errorDark` text, dismissible) · forgot-password confirm dialog + success/warning snackbars.
**Copy:** "Email", "Password", "Sign in", "Forgot password?", "Sign in to your account".

---

## Screen 2 — Dashboard  (`lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`)

**Job:** orient the user and launch the day's work. **Role-aware.**

**App bar:** greeting (time-based: Good morning/afternoon/evening, bodySmall muted) + display name (titleMedium
600). Actions: **void-requests bell** (admin only; red unread badge) · settings · sign-out.

**Pinned header (stays while body scrolls):** date row (calendar icon + `Friday, June 20, 2026`, muted 500) →
**Quick Actions** — horizontal-scroll pill row. `New Sale` is the single **filled** primary (brand slate);
the rest are **outlined hairline** (`Receive Stock`, `Inventory`, `Expenses`, `Reports`); `Close Day` is
**error-outlined**. Each = icon + label, radius `lg`.

**Scrolling body:**
1. **Today's Sales** — `SummaryCard`s. *Admin:* 2×2 grid — Gross Sales (+discount subtitle) · Avg Daily Sales
   (this month) · Total COGS · Gross Profit (margin %); + a Service/Labor card when labor > 0. *Staff/cashier:*
   a single full-width **Gross Sales** card only. Card = flat white, hairline border, radius `lg`, muted icon
   top-left, title (14 muted), **value (24/600, the hero)**, optional subtitle.
2. **Top Selling Items Today** + `View All` → ranked product rows.
3. **Recent Transactions** + `View All` → recent sale rows (sale #, time, payment chip, amount), `limit 5`.

**Components:** `QuickActions`, `SalesSummarySection` → `SummaryCard`, `TopSellingTodayWidget`,
`RecentSalesWidget`, `LoadingOverlay`. Pull-to-refresh invalidates today's summary/sales/inventory.
**States:** loading · error (with "Go to Login") · null-user redirect · per-section loading/empty · signing-out overlay.
**Role rules:** all roles → New Sale, Inventory, Expenses, Reports; staff+admin → Receiving; admin → profit
cards + void bell + Close Day.

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name a screen, a region, and the change.

### Direction / mood
- Keep or change the airy-minimal direction? →
- Reference apps / vibes you like (and why) →
- Anything that currently feels off / dated / generic →

### Brand
- Logo/wordmark treatment for `MAKI POS` →
- Palette: keep slate `#334E58` + gold `#E8B84C`, or shift? New accents? →
- Typeface: keep Roboto, or a distinctive display face for headings/numbers? →

### Login — specific wants
- Hero / first impression →
- Layout, spacing, imagery, motion →

### Dashboard — specific wants
- The greeting/app-bar →
- Quick Actions (treatment, order, which are primary) →
- Today's Sales cards (hierarchy, what's the hero metric) →
- Top Selling / Recent Transactions (list style) →
- Anything to add or remove →

### Constraints / must-keep
- Role-gating (cashier vs admin views) must stay →
- Dark theme parity needed? →
- Accessibility / font-size / one-handed reach notes →

---

*Next screens queued (per the 39-screen inventory): POS · Checkout · Inventory · Reports · … — one bundle at a time.*
