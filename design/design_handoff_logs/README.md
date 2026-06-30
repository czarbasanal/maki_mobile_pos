# Bundle 13 — Logs

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (1 real screen, 5 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **Activity Logs** feed (date-grouped audit trail) | `lib/presentation/mobile/screens/logs/activity_logs_screen.dart` |
| 2 | **Filter by type** popup menu | same (`PopupMenuButton<ActivityType?>`) |
| 3 | **Active filter** applied (chip strip) | same (`Chip` + hairline strip) |
| 4 | **Empty** state | same (`Center` + Cupertino clock) |
| 5 | **Loading** state | same (`LoadingView` from `state_views.dart`) |

Supporting types/widgets:

| Thing | Source |
|---|---|
| Log entity + action enum | `lib/domain/entities/activity_log_entity.dart` (`ActivityLogEntity`, `ActivityType`) |
| Data | `lib/presentation/providers/activity_log_provider.dart` (`activityLogsStreamProvider`, auth-gated, limit 100) |
| Shared state views | `lib/presentation/shared/widgets/common/state_views.dart` (`LoadingView`, `ErrorStateView`) |
| Route + guard | `app_routes.dart` (`/logs` → `ActivityLogsScreen`), `route_guards.dart` (`Permission.viewUserLogs`) |

Reached from Settings. **Admin-only** (`Permission.viewUserLogs`).

> ⚠️ **Two files, one screen.** `lib/presentation/mobile/screens/logs/user_logs_screen.dart` exists but is a
> **0-byte empty stub** — it was never implemented and is not referenced anywhere. The `/logs` (a.k.a. `userLogs`)
> route mounts `ActivityLogsScreen`. There is **no separate per-user / login-history screen** today. If a distinct
> "user logs" view is wanted, that's net-new scope, not a restyle.

## Current state — what's not migrated

Raw Material: a `ListView.builder` of flat `Container` rows separated by hairline `Border`s, grouped under
uppercase date headers. The app-bar filter is a `PopupMenuButton`; the active filter shows as a Material `Chip`.
Leading glyph for each row is an **emoji** (from `ActivityType.emoji`) inside an outlined circle. Icons are
**Cupertino** (`back`, `line_horizontal_3_decrease`, `xmark`, `person`, `clock`). **No `AppCard`, no Lucide**, and
the action glyph is an emoji rather than a semantic icon. Color is already disciplined: the glyph circle border is
the only accent — `AppColors.error` for security events, `AppColors.success` for financial events,
hairline-neutral otherwise. This bundle = Cupertino + emoji → Lucide + semantic icons, Material rows →
soft-shadow `AppCard`, and formalize the action-type color semantics with dark parity.

## States & rules to preserve (don't design these away)

- **Read-only audit trail.** No edit, no delete, no tap-through. Logs are immutable history.
- **Admin-only.** Gated by `Permission.viewUserLogs`; do not expose to cashier.
- **Date grouping.** Logs grouped by calendar day, newest first, under an uppercase header:
  `Today` / `Yesterday` / else `EEEE, MMMM d, y` (e.g. `MONDAY, JUNE 23, 2026`). Header is flat with hairline
  top+bottom borders.
- **Log row** = leading glyph circle + body. Body: `action` (medium weight) with a right-aligned `h:mm a` time on
  the same line; optional `details` (muted) below; then an **actor line** = `person` icon + `userName` + a
  **role badge** (outlined pill, e.g. `admin` / `cashier`).
- **Per-action glyph.** Each `ActivityType` has a `displayName` + `emoji` (🔑 login, 🚪 logout, 💰 sale, ❌ void,
  ↩️ refund, 📦 inventory, 📊 stock adjust, 📥 receiving, 👥 user mgmt, ➕ user created, ✏️ user updated, 🔄 role
  changed, 🛡️ security, ✅ password verified, ⚠️ password failed, 👁️ cost viewed, ⚙️ settings, 🔢 cost code, 🧾
  expense, 🚚 supplier, 📒 day closed, 📝 other). When migrating to Lucide, map each type to a semantic icon and
  keep the categorical legibility (don't collapse them to one generic icon).
- **Action-type color semantics.** Reserve color for audit-meaningful events only:
  `isSecurityRelated` (security / authentication / user-management / password verified / password failed) → **error**;
  `isFinancialAction` (sale / void / refund) → **success**; everything else **neutral**. Today this colors only
  the glyph circle border — keep the neutral-by-default discipline.
- **Type filter.** App-bar `PopupMenuButton` listing `All Activities` + a divider + 12 common types (login, logout,
  sale, void sale, stock adjustment, receiving, user created, user updated, role changed, password verified,
  password failed, cost viewed), each with its emoji. Selecting a type filters the stream
  (`ActivityLogParams.type`). When a filter is active, show a removable **chip strip** below the app bar
  (emoji + display name + delete) that clears the filter.
- **Empty state:** clock icon + "No activity logs found".
- **Loading state:** `LoadingView`. **Error state:** `ErrorStateView` with a retry that invalidates the stream.
- Dates `h:mm a` for row time; full date in the group header.

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–12: soft-shadow `AppCard`
rows, **Lucide** icons (replace Cupertino + the emoji glyph with semantic per-type Lucide icons), theme-aware
**action-type color semantics** with dark parity (reuse `AppColors` error/success + their `*OnDark` variants, keep
color reserved for security/financial events), neutral-by-default discipline. Date-group header and active-filter
chip strip stay flat on canvas; the app bar stays flat. Match the date-grouped feed styling already shipped in
related history/list bundles.
