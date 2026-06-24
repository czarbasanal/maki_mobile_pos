# Handoff: MAKI POS — Global App Theme (Login & Dashboard)

## Overview
This bundle defines a refreshed **global visual theme** for the MAKI POS Flutter app, demonstrated on the two
existing screens: **Login** and **Dashboard** (admin). The direction keeps the original airy-minimal feel but
**elevates surfaces off the background with soft shadows (Airbnb-style)** and establishes a clear hierarchy where
the value/number is the hero. Both **light and dark** themes are specified, since the app ships a theme toggle.

The intent is for this to become the app-wide theme (`lib/core/theme/`), not a one-off screen restyle. Apply the
tokens and component patterns below to every screen as they are migrated.

## About the Design Files
The files in this bundle are **design references created in HTML** — a prototype showing the intended look and
behavior. **They are not production code to copy.** The task is to **recreate these designs in the existing Flutter
codebase** (`lib/`) using its established widget patterns (`AppTextField`, `AppButton`, `SummaryCard`,
`QuickActions`, etc.) and theme layer (`lib/core/theme/`). Translate the CSS values below into Flutter
`ThemeData`, `ColorScheme`, `TextTheme`, and widget styles.

- `MAKI POS Theme.dc.html` — the redesign prototype (open in a browser). Login + Dashboard, light + dark, plus a
  token reference strip at the top.
- `reference_current-ui.html` — the **previous/current** UI, for before/after comparison only.

## Fidelity
**High-fidelity (hifi).** Colors, typography, spacing, radii, shadows, and icon treatment are final. Recreate the
UI to match, using Flutter equivalents of the values listed under **Design Tokens**.

---

## Design Tokens

### Color
| Token | Hex | Use |
|---|---|---|
| `slate` (primary) | `#283E46` | **Light-theme primary** — filled buttons, New Sale pill, avatar/logo tile, focus ring, links. *(Darkened from the old `#334E58`.)* |
| `gold` (accent) | `#E8B84C` | Accent. **In dark theme this becomes the primary** — Sign-in button, New Sale pill, logo tile, avatar, links, focus ring. Trend chip in both themes. |
| `ink` | `#121C1D` | Brand ink · dark-theme background · text on gold. |

**Light theme**
| Role | Hex |
|---|---|
| Screen background (behind cards) | `#F6F5F3` |
| Card / elevated surface | `#FFFFFF` |
| Input fill (resting) | `#FAFAFA` |
| Text primary | `#16201F` |
| Text secondary / muted | `#8A9296` (also `#6A7378`, `#5A6468`) |
| Text hint | `#9AA0A3` / `#B4B4B4` |
| Hairline / border | `#ECECEC` · input border `#E2E2E2` · row divider `#F0F0F0` |

**Dark theme**
| Role | Hex |
|---|---|
| Screen background | `#0C1415` |
| App bar / status bar surface | `#121C1D` |
| Card / elevated surface | `#18262A` |
| Border / hairline | `#243234` (input border `#2C3C3E`) |
| Text primary | `#ECEFEF` (pure `#FFFFFF` for the hero number & title) |
| Text secondary / muted | `#93A0A3` |
| Text hint | `#6C797C` / `#566163` |

**Status & payment (shared)**
| Token | Hex | Notes |
|---|---|---|
| cash / success | `#4CAF50` | Light chip: text `#2E7D32` on `#E8F5E9`. Dark chip: text `#8FE39A` on `rgba(76,175,80,.18)`. |
| gcash | `#007DFE` | Light chip: text `#024A99` on `#E3F0FF`. Dark chip: text `#7FB6FF` on `rgba(0,125,254,.2)`. |
| draft | `#FF9800` | |
| error | `#F44336` | Close Day outline; notification badge. Dark outline text `#FF6B5E`. |
| profit-positive | `#4CAF50` (light) / `#5FC86A` (dark) | Profit stat icon. |

### Typography
- **Primary family: `Figtree`** (Google Fonts) — replaces Roboto app-wide. Weights used: 400/500/600/700.
- **Monospace: `Roboto Mono`** (500/600) — sale numbers / SKUs / codes only.

| Style | Size / Weight | Usage |
|---|---|---|
| Hero value | 38 / 700, letter-spacing −1px | Gross Sales number (decimals at 22px, muted) |
| Heading | 30 / 700, letter-spacing −.6px | Page title (artboard only) |
| Section header | 16 / 700 | "Today's Sales", "Top Selling Today", "Recent Transactions" |
| Stat value | 18 / 700 | Avg Daily / COGS / Profit cards |
| Name / display | 16 / 600 | User name in app bar |
| Body | 14–15 / 400–500 | Field text, list item names, date row |
| Label | 11–13 / 500–600 | Card labels, greeting, captions |
| Chip / badge | 10–11 / 600, uppercase, letter-spacing .4px | Payment chips, trend chip |
| Mono code | 12 / 600, letter-spacing .3px | `SALE-20260620-014` |
| Logo wordmark | 18 / 700, letter-spacing **2.4px** | "MAKI POS" |

### Spacing
Base scale (unchanged from app): `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`.
Screen horizontal padding 18px; card internal padding 14–22px; section gap 24px.

### Radius
| Name | Value | Use |
|---|---|---|
| field / button / pill / supporting card | `16px` | Inputs, primary button, quick-action pills, stat cards |
| list card | `18px` | Top Selling / Recent Transactions containers |
| hero card | `22px` | Gross Sales hero |
| logo / avatar tile | `14–20px` | Avatar 14, logo 20 |
| icon thumbnail | `11px` | Product placeholder squares |
| pill / badge | `999px` | Status chips, notification badge, icon-button hit area |

### Elevation (shadows) — the defining change
Surfaces lift with **soft, low-opacity shadows** (light theme); dark theme uses a 1px border + a deeper shadow.

| Level | Light theme | Dark theme |
|---|---|---|
| rest | `0 1px 3px rgba(17,28,29,.06–.08)` | border `1px #243234` |
| card | `0 2px 8px rgba(17,28,29,.06)` + `0 1px 2px rgba(17,28,29,.05)` | border `1px #243234` |
| hero | `0 10px 28px -10px rgba(17,28,29,.16)` + `0 2px 6px rgba(17,28,29,.05)` | `0 10px 28px -10px rgba(0,0,0,.55)` + border |
| primary button (slate) | `0 8px 20px -6px rgba(40,62,70,.55)` | gold: `0 8px 22px -6px rgba(232,184,76,.5)` |
| New Sale pill | `0 6px 16px -4px rgba(40,62,70,.5)` | gold: `0 6px 16px -4px rgba(232,184,76,.45)` |
| focus ring | `0 0 0 4px rgba(40,62,70,.08)` (border `1.5px #283E46`) | `0 0 0 4px rgba(232,184,76,.12)` (border `1.5px #E8B84C`) |

In Flutter, approximate these with `BoxShadow` (e.g. `BoxShadow(color: const Color(0x14111C1D), blurRadius: 28,
offset: Offset(0,10), spreadRadius: -10)` for the hero). Material `elevation` alone will not match — use explicit
`BoxShadow` lists on `Container`/`Card(shadowColor/elevation)`.

### Icons — **Lucide**
Switched from Material Symbols to **Lucide** (`lucide_icons` package). Minimalist, uniform **stroke 1.75**, rounded
caps. Default size 18–22px; set a default via `IconThemeData`.

| Where | Lucide name |
|---|---|
| Gross Sales (hero) | `wallet` |
| New Sale | `shopping-cart` |
| Receive | `download` |
| Inventory | `package` |
| Close Day | `calendar-x` |
| Avg Daily | `bar-chart-3` (`barChart3`) |
| COGS | `boxes` |
| Profit / trend chip | `trending-up` |
| Notifications | `bell` |
| Settings | `settings` |
| Sign out | `log-out` (`logOut`) |
| Date row | `calendar` |
| Email field | `mail` |
| Password field | `lock` · toggle `eye-off` (`eyeOff`) |
| Theme labels | `sun` / `moon` |
| Status bar | `signal-high`, `wifi`, `battery-full` |

Flutter usage: `Icon(LucideIcons.wallet, size: 18, color: ...)`. The mock renders Lucide via the web library
(`<i data-lucide="…">` + `lucide.createIcons()`) — that is a prototype detail only; use the package in Flutter.

---

## Screens / Views

### Screen 1 — Login  (`lib/presentation/shared/screens/auth/login_screen.dart`)
**Purpose:** sign a user in. Single centered column, `maxWidth ≈ 330`, screen padding 30px.

**Layout (top → bottom), vertically centered:**
1. **Logo tile** — 74×74, radius 20. *Light:* slate `#283E46` fill, white `マ` glyph (30/700), shadow
   `0 10px 24px -6px rgba(40,62,70,.5)`. *Dark:* gold `#E8B84C` fill, ink `マ`, gold shadow.
2. **Wordmark** "MAKI POS" — 18/700, letter-spacing 2.4px. Light `#121C1D`, dark `#FFFFFF`. Margin-top 22.
3. **Subtitle** "Sign in to your account" — 14, muted. Margin-top 8.
4. **Email field** (margin-top 38) — label "Email" (12/500 muted, 2px left inset, 7px below) above a 54px-tall
   box: radius 16, light border `#E2E2E2` on `#FAFAFA` fill / dark border `#2C3C3E` on `#18262A`. Leading
   `mail` icon (20px, hint color), then value text (15px). Sample: `juan@makipos.ph`.
5. **Password field** (margin-top 16) — shown in **focused** state: border `1.5px` slate(light)/gold(dark),
   focus ring shadow, label colored slate/gold. Leading `lock` icon (slate/gold), masked value `••••••••••`,
   trailing `eye-off` toggle (hint color).
6. **Sign-in button** (margin-top 26) — full width, 54px, radius 16. *Light:* slate fill, white text.
   *Dark:* gold fill, ink text. Text 16/600, letter-spacing .4px. Elevated shadow (see tokens).
7. **"Forgot password?"** — 13/500, slate(light)/gold(dark), centered, margin-top 14.
8. **`v1.0.0`** — 11, hint, pinned 30px from bottom, centered.

**States to implement (from current app):** default · loading overlay ("Signing in…") · field validation errors ·
dismissible auth-error banner (`errorLight` bg, error icon, `errorDark` text) · forgot-password confirm dialog +
success/warning snackbars.

### Screen 2 — Dashboard  (`lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`)
**Purpose:** orient the user and launch the day's work. **Role-aware** (admin shown here).

**A. Status bar** — 36px; time left, signal/wifi/battery right. Surface matches app bar (`#FFFFFF` / `#121C1D`).

**B. App bar + pinned header** — one **elevated white(light)/ink(dark) surface** with a soft bottom shadow
(`0 2px 10px rgba(17,28,29,.05)` / `0 2px 12px rgba(0,0,0,.4)`), padding `6px 18px 16px`, sits above the scroll
body (`z-index` above). Contains:
- **App bar row** (56px): left = **avatar tile** (42×42, radius 14, slate(light)/gold(dark) fill, initials "JD"
  15/600, shadowed) + greeting ("Good morning", 13 muted) over name ("Juan Dela Cruz", 16/600). Right = three
  40px circular icon buttons: `bell` (with red `#F44336` unread badge "3", 2px surface-colored ring — **admin
  only**), `settings`, `log-out`.
- **Date row**: `calendar` icon (18) + "Friday, June 20, 2026", 14/500 muted.
- **Quick Actions** (margin-top 16): horizontal-scroll pill row, gap 10, right-edge fade mask. Pills are 50px
  tall, radius 16, icon (20) + label (14/600).
  - **New Sale** — primary filled: slate(light)/gold(dark), elevated shadow. The single primary.
  - **Receive**, **Inventory** — outlined: white/`#18262A` surface, hairline border, muted icon.
  - **Close Day** — error outlined: 1px `#F44336` border, error text (`#F44336` light / `#FF6B5E` dark).
  - (Off-screen right, per role: Expenses, Reports. Scroll reveals them.)

**C. Scroll body** (padding `18px 18px 24px`):
1. **Today's Sales** section header (16/700).
   - **Gross Sales HERO card** (radius 22, hero shadow): top row = `wallet` icon + "Gross Sales" (13/500 muted)
     on the left, **trend chip** on the right (`trending-up` 14px + "12% vs yest", 11/600; gold-tint bg
     `#FBF3DE`/text `#9A7B1F` light, `rgba(232,184,76,.16)`/`#E8B84C` dark). Then the **hero value**
     `₱12,480` at 38/700 (decimals `.00` at 22px muted). Subtitle "₱320.00 discount applied · 14 sales"
     (13 muted). **Gross Sales is the hero metric.**
   - **Supporting stats** — 3-up grid (`1fr 1fr 1fr`, gap 10), each a card (radius 16, card shadow / dark border):
     icon (18, muted; Profit icon green) → label (11 muted) → value (18/700). Cards: **Avg Daily** `₱9.8K`
     (`bar-chart-3`), **COGS** `₱7.1K` (`boxes`), **Profit** `₱5.4K` (`trending-up`, green icon).
     *(These three are admin-only; cashier/staff see only the Gross Sales hero — see Role rules.)*
2. **Top Selling Today** — section header + "View All" link (13/500, slate/gold). Card (radius 18) holding rows:
   product thumbnail placeholder (40×40, radius 11, striped gray) + name (14/600, ellipsis) over qty ("8 sold",
   12 muted) + amount (14/600, right). Rows divided by hairline. Sample: "Shimano Brake Pad B01S / 8 sold /
   ₱2,400", "Engine Oil 1L · 10W-40 / 6 sold / ₱1,770".
3. **Recent Transactions** — section header + "View All". Card holding rows: mono sale # (`SALE-20260620-014`,
   12/600) over time·items ("9:32 AM · 3 items", 12 muted) + **payment chip** (cash/gcash, see tokens) + amount
   (14/600, right, min-width 56 right-aligned). `limit 5`.

**States to implement:** loading · error (with "Go to Login") · null-user redirect · per-section loading/empty ·
signing-out overlay. Pull-to-refresh invalidates today's summary/sales/inventory.

---

## Interactions & Behavior
- **Quick Actions** scroll horizontally; the right-edge fade hints at more. New Sale is the only filled action.
- **Password visibility** toggled by the trailing `eye-off`/`eye` icon.
- **Notification bell** opens void-requests (admin); badge shows unread count.
- **View All** links navigate to the full Top Selling / Recent Transactions lists.
- **Theme toggle** swaps the full light/dark token set (see both columns of every token table). Animate the
  transition if the app already does; otherwise instant is fine.
- Card press states: a subtle scale/opacity or ripple consistent with the rest of the app is acceptable; the mock
  is static.

## State Management
Reuse the app's existing providers/blocs. Data needed per screen:
- **Login:** email, password, obscure-password bool, loading, auth-error message.
- **Dashboard:** current user (name, role), today's summary (gross, discount, sale count, avg daily, COGS, profit
  + margin, trend %), top-selling list, recent-transactions list, unread void-request count. Loading/empty/error
  per section; pull-to-refresh invalidation.

## Role rules (must keep)
- All roles → New Sale, Inventory, Expenses, Reports quick actions.
- Staff + admin → Receiving (Receive). Admin → profit/COGS/avg cards, void-requests bell, Close Day.
- **Cashier / staff dashboard:** a single full-width **Gross Sales** hero card only — no supporting stat grid.

## Assets
- **Icons:** Lucide (`lucide_icons` package). No custom SVGs.
- **Fonts:** Figtree + Roboto Mono (Google Fonts; bundle for offline or use `google_fonts`).
- **Logo:** placeholder `マ` glyph in a rounded tile — replace with the real MAKI mark if/when available.
- **Product thumbnails:** striped placeholders in the mock; wire to real product images, falling back to the
  placeholder.

## Screenshots
- `screenshots/01-overview-tokens.png` — title + token reference strip (brand, status, elevation, Lucide icons).
- `screenshots/02-light-theme.png` — Login + Dashboard, light theme.
- `screenshots/03-dark-theme.png` — Login + Dashboard, dark theme.

## Files
- `MAKI POS Theme.dc.html` — the redesign prototype (Login + Dashboard, light + dark, token strip). Source of
  truth for this handoff.
- `reference_current-ui.html` — previous UI, for before/after only.
- `screenshots/` — rendered reference images of the prototype.
