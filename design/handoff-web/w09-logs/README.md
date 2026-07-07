# MAKI POS Web Admin — Design Handoff w09: Activity Logs

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the Activity Logs feature
(a read-only, day-grouped audit trail with a type filter) so a design session can *see* what exists today
and mark up what should change. Hand the marked-up version back and it gets implemented in React (Vite +
TypeScript + Tailwind, `web_admin/`). This bundle is desktop, light-theme only — the theme the web admin
actually ships.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of the Activity Logs screen
  (populated day groups + all states) plus the TypeFilter popover, rendered inside the 240px admin sidebar
  chrome, light theme.
- `README.md` (this file) — the design system, the screen's structure/copy/states/role rules, the full
  **type → tone** and **type → icon** tables, the modals section, and a **"What I want" template** to fill
  in and hand back.

**Surfaces.** React web admin:
- `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx` — the whole feature: page header,
  `TypeFilter` popover, day grouping, `LogRow`, tone/icon maps, all states.

Shared components reused: `LoadingView`/`Spinner`, `ErrorView`, `EmptyState` (from
`web_admin/src/presentation/components/common/`); `Sidebar` + `AdminShell` chrome; `toneBadgeClasses` from
`core/theme/tones.ts`; activity enums + display names + `isSecurityActivity`/`isFinancialActivity` from
`domain/entities/ActivityLog.ts`; data via `useActivityLogs({ type, limit: 200 })`.

---

## Design system (tokens in `web_admin/src/core/theme/tokens.ts`, surfaced via `tailwind.config.ts`)

### Colors used by this screen
| Token | Hex | Use here |
|---|---|---|
| `light-text` | `#0A0A0A` | page title, row `action` primary text, filter-trigger label |
| `light-text-secondary` | `#666666` | subtitle, details paragraph, day-header label, role-pill text |
| `light-text-hint` | `#A0A0A0` | right-aligned row time, meta line (user icon + name), section labels |
| `light-background` | `#FFFFFF` | page / sidebar; sticky day-header bg is `bg-light-background/80` + `backdrop-blur` |
| `light-card` | `#FFFFFF` | the grouped list card, popover surface |
| `light-subtle` | `#FAFAFA` | filter-trigger hover, popover-item hover, role-pill background |
| `light-hairline` / `light-divider` | `#EAEAEA` | list card border, row dividers, day-header bottom border, popover divider |
| `light-border` | `#E0E0E0` | filter-trigger (outlined button) border |
| `error` base | `#F44336` | `ErrorView` icon (`text-error`) |

Tonal palette (`core/theme/tones.ts`, `toneBadgeClasses` = `bg-{tone}-50 text-{tone}-600`, standard Tailwind scale) — drives the type-icon squares and the popover mini-squares:

| Tone | bg (`-50`) | icon (`-600`) |
|---|---|---|
| yellow | `#FEFCE8` | `#CA8A04` |
| green | `#F0FDF4` | `#16A34A` |
| blue | `#EFF6FF` | `#2563EB` |
| orange | `#FFF7ED` | `#EA580C` |
| red | `#FEF2F2` | `#DC2626` |
| violet | `#F5F3FF` | `#7C3AED` |

### Type scale (custom `fontSize`; px / weight)
`headingMedium` 24/600 (page `h1`) · `bodyMedium` 16/400 → **medium (500)** for the row `action` · `bodySmall`
14/400 (subtitle, details paragraph, filter trigger + popover items) · ad-hoc `text-[11px]` semibold uppercase
(day-header label, section labels) · `text-[12px]` (row time, meta line) · `text-[10px]` semibold uppercase
(role pill).

### Spacing (custom `tk-*`) & radii
Spacing: `tk-xs` 4 · `tk-sm` 8 · `tk-md` 16 · `tk-lg` 24 · `tk-xl` 32 · `tk-xxl` 48.
Page shell `space-y-tk-xl px-tk-xl py-tk-lg`; groups `space-y-tk-lg`; rows `p-tk-md gap-tk-md`.
Radii (Tailwind defaults): `rounded-md` 6px (filter trigger, popover, type/mini icon squares) ·
`rounded-lg` 8px (list card) · `rounded-full` (role pill). Shadows: `shadow-lg` on the popover only;
the list card carries no shadow — weight is hairline + type.

### Button / control styles (this screen is read-only — no CTAs)
- **Filter trigger** — outlined button: `border border-light-border`, white fill, hover `bg-light-subtle`;
  `FunnelIcon` (3.5) + current label + `ChevronDownIcon` (3.5).
- **Popover items** — full-width ghost rows, hover `bg-light-subtle`; selected item is `font-semibold`.

### Card / list pattern
The grouped list is a rounded hairline card (`overflow-hidden rounded-lg border border-light-hairline
bg-light-card divide-y divide-light-hairline`) per day group. Each **day group** = a sticky uppercase
`text-[11px]` header (`bg-light-background/80 backdrop-blur`, bottom hairline, negative `-mx-tk-xl` so it
bleeds to the scroll-region edges) over that group's card of `LogRow`s.

---

## Screen — Activity logs  (`/logs`)

**Job.** Read-only audit trail of everything users do across **both** the web admin and the Flutter mobile
app (they write to the same `user_logs` collection). Mirrors the Flutter `activity_logs_screen.dart`. Lets an
admin filter by activity type and scan a reverse-chronological, day-grouped feed with tone-coded icons.
Sets `document.title = "Activity logs · MAKI POS Admin"`. Data via `useActivityLogs({ type, limit: 200 })`;
`type` starts `null` (all).

**Layout, top → bottom:**
1. **Header row** (`flex justify-between`, wraps) — left: `h1` **"Activity logs"** (headingMedium semibold) +
   subtitle *"Real-time audit trail of user actions across both web and mobile clients."* (bodySmall,
   secondary). Right: the **TypeFilter** popover trigger (see Modals).
2. **Body** — one of: grouped list (populated) · `LoadingView` · `EmptyState` · `ErrorView` (see states).
3. **Grouped list** — logs are bucketed by calendar day (client-side, in fetch order = newest first). Each
   group renders a **sticky day header** then a card of rows:
   - **Day header label** — **"Today"** / **"Yesterday"** / else the full `en-PH` date
     (weekday · month · day · year, e.g. *"Friday, July 4, 2026"*).
   - **LogRow** (per entry, top → bottom / left → right):
     - **Type square** — 9×9 (`h-9 w-9`) rounded tinted square, `toneBadgeClasses[tone]`, with the type's
       16px heroicon centered. Tone + icon are derived from `log.type` (tables below).
     - **Primary line** — `log.action` (the human sentence written at log time), falling back to the
       type's display name when `action` is empty; bodyMedium **medium**. Right-aligned on the same line:
       the **time** (`en-PH`, `h:mm a`, e.g. *"10:15 AM"*), `text-[12px]` hint.
     - **Details paragraph** *(optional)* — `log.details` when present; bodySmall secondary.
     - **Meta line** — `UserIcon` (12px) + `log.userName` (or **"—"** when blank); then, when `log.userRole`
       is present, a **role pill** — `rounded-full bg-light-subtle` `text-[10px]` semibold uppercase, plain
       **grey** (this screen does NOT tone-color the role pill, unlike the Users list `RoleBadge`).

**UI states:**
- **Loading** (`isLoading` or no data yet) → `LoadingView` label *"Loading logs…"*.
- **Empty** (0 groups) → `EmptyState` title *"No activity yet"*. Description **varies by filter**:
  - no filter → *"Logs will appear here as users sign in and take actions."*
  - a type is selected → *"No {Type display name} entries match this filter."* (e.g. *"No Void Sale entries match this filter."*)
- **Error** → `ErrorView` title *"Could not load logs"* + `error.message` (replaces the list region).
- **Populated** → the day-grouped list.

**Per-role differences.** **Admin-only.** `/logs` is gated by `viewUserLogs` (admin-only in `Permission.ts`),
and the web app additionally bounces every non-admin at the door (`ProtectedRoute` → `/access-denied`). So
**staff and cashier never see the Activity Logs sidebar item and never render this screen.** There is **no
in-page role branching** — an admin who reaches the page sees every row and control. The screen is fully
**read-only**: no create/edit/delete, no row actions, no dialogs beyond the filter popover.

### Type → tone mapping (`toneFor`)
Precedence: **security first, then financial, then a type switch, else blue (default).**

| Tone | Types |
|---|---|
| **red** (security) | `security`, `authentication`, `user_management`, `password_verified`, `password_failed` (via `isSecurityActivity`) |
| **green** (financial) | `sale`, `void_sale`, `refund` (via `isFinancialActivity`) |
| **blue** (inventory/stock/receiving) | `inventory`, `stock_adjustment`, `receiving` — **plus the default** for anything not otherwise mapped: `login`, `logout`, `cost_viewed`, `supplier`, `other` |
| **violet** (user management) | `user_created`, `user_updated`, `user_deactivated`, `role_changed` |
| **orange** (settings) | `settings`, `cost_code_changed` |
| **yellow** (expense) | `expense` |

> Note the ordering consequences worth keeping: `void_sale` resolves **green** (financial) not red;
> `login`/`logout` and `cost_viewed` fall through to the **blue** default (they are not in `isSecurityActivity`).

### Type → icon mapping (`ICONS`, heroicons 24/outline)
| Type | Icon |
|---|---|
| `authentication`, `security` | `ShieldCheckIcon` |
| `login`, `logout` | `ArrowRightOnRectangleIcon` |
| `sale` | `CurrencyDollarIcon` |
| `void_sale` | `XCircleIcon` |
| `refund` | `ArrowUturnLeftIcon` |
| `inventory` | `CubeIcon` |
| `stock_adjustment` | `ArrowPathIcon` |
| `receiving` | `TruckIcon` |
| `user_management` | `UsersIcon` |
| `user_created` | `UserPlusIcon` |
| `user_updated` | `UserIcon` |
| `user_deactivated` | `UserMinusIcon` |
| `role_changed` | `KeyIcon` |
| `password_verified` | `LockClosedIcon` |
| `password_failed` | `ExclamationTriangleIcon` |
| `cost_viewed` | `EyeIcon` |
| `settings` | `Cog6ToothIcon` |
| `cost_code_changed` | `CodeBracketSquareIcon` |
| `expense` | `ReceiptPercentIcon` |
| `supplier` | `BuildingStorefrontIcon` |
| `other` (+ unknown fallback) | `ClipboardDocumentListIcon` |

**Activity type display names** (`activityTypeDisplayName`, used in the filter, empty-state copy, and as the
row primary fallback): Authentication · Login · Logout · Sale · Void Sale · Refund · Inventory ·
Stock Adjustment · Receiving · User Management · User Created · User Updated · User Deactivated · Role Changed ·
Security · Password Verified · Password Failed · Cost Viewed · Settings · Cost Code Changed · Expense ·
Supplier · Other.

**Icons on this screen (heroicons 24/outline):** `FunnelIcon`, `ChevronDownIcon`, `UserIcon`, plus the full
type-icon set above (rendered inside the tinted squares), and `ExclamationCircleIcon` (via `ErrorView`).

---

## Modals & overlays

- **TypeFilter dropdown popover** (`TypeFilter`, local to the page — the only overlay on this screen).
  - **Trigger** — outlined button (`border-light-border`, hover `bg-light-subtle`): `FunnelIcon` (3.5) +
    current label (**"All activities"** when unfiltered, else the selected type's display name) +
    `ChevronDownIcon` (3.5). Toggles the menu.
  - **Menu** — absolute, right-aligned (`right-0`), `mt-tk-xs`, `w-64`, `max-h-80` scrollable,
    `rounded-md border border-light-hairline bg-light-card shadow-lg`. Contents:
    1. **"All activities"** row (clears the filter). Selected when no type is active → `font-semibold
       text-light-text`; otherwise `text-light-text-secondary`.
    2. A hairline **divider**.
    3. The **`COMMON_TYPES`** list, in order: **Login · Logout · Sale · Void Sale · Stock Adjustment ·
       Receiving · User Created · User Updated · Role Changed · Password Verified · Password Failed ·
       Cost Viewed · Cost Code Changed** — each row = a **6×6 tinted mini-square** (`toneBadgeClasses[tone]`,
       14px icon) + the type's display name. The currently-selected type is `font-semibold`.
  - **Behavior** — opening renders a `fixed inset-0` transparent overlay; **clicking outside** (the overlay)
    closes the menu. Selecting any row sets the filter (or clears it for "All activities") and closes. No
    pending/lock state — it's a pure client-side filter that re-queries `useActivityLogs`.

*(No dialogs, confirms, or mutation overlays exist on this screen — it is read-only.)*

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the region + the change.

### Direction
- Overall: restyle Activity Logs within the current layout, or rethink the structure? →
- Reference apps / audit-log UIs whose look you like →

### Header & filter
- **Filter control** — keep the single outlined type-filter popover, or a different affordance
  (segmented chips, a search box, multi-select)? Keep it read-only / single-select? →
- **Day grouping** — keep sticky "Today / Yesterday / full date" headers on a blurred bg, or a different
  time treatment (relative timestamps, a left timeline rail)? →

### Log rows
- **Type square** — keep the 9×9 tone-tinted icon square, or a different type indicator (left color bar,
  pill, plain icon)? Keep the 6-tone palette (security-red / financial-green / inventory-blue /
  user-violet / settings-orange / expense-yellow)? →
- **Row layout** — keep action + right-aligned time on line 1, details paragraph, then user + role-pill meta
  line? Any hierarchy change (e.g. lead with user, or with time)? →
- **Role pill** — keep it plain grey here, or tone-color it to match roles like the Users list does? →
- **Charts** — allowed only if visualizing data already on this screen (e.g. a small activity-by-type
  or activity-over-time bar). Want one? Where? →

### Constraints / must-keep
- **Admin-only, read-only** screen (`viewUserLogs`; also door-gated to admins). No row actions, no
  mutations, no dialogs beyond the filter popover. Do not add any. →
- The **type filter** stays: "All activities" + the 13 `COMMON_TYPES` (Login · Logout · Sale · Void Sale ·
  Stock Adjustment · Receiving · User Created · User Updated · Role Changed · Password Verified ·
  Password Failed · Cost Viewed · Cost Code Changed), each with its tinted icon; selected = semibold;
  click-outside dismiss. →
- **Day grouping** with Today / Yesterday / full `en-PH` date headers stays. →
- Every **LogRow** part stays: type icon (tone + icon per the tables), `action` (fallback = type name),
  right-aligned `en-PH` time, optional `details` paragraph, user icon + userName (or "—"), optional role pill. →
- The full **type → tone** and **type → icon** mappings stay exactly as tabled above. →
- All states stay: loading (*"Loading logs…"*), empty **both copies** (*"No activity yet"* + the filtered vs
  unfiltered description), error (*"Could not load logs"*), populated. →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · w03-inventory · w04-receiving ·
w05-suppliers · w06-reports · w07-users · w08-settings · **w09-logs (this)**.*
