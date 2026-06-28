# Bundle 10 — Settings

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

> **Largest bundle.** This covers 6 screens + several dialogs/sheets. It can reasonably be **split** into
> two slices if it's too big to design in one pass — suggested split: **10a Hub + General/About** (frames
> 1–3, 9) and **10b Admin editors** (Manage Lists, Category editor, Cost Codes, Mechanics — frames 4–8).

## Scope (6 screens + shared widgets, 9 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **Settings hub** — admin view (My Profile / Administration / General) | `lib/presentation/mobile/screens/settings/settings_screen.dart` |
| 2 | **Settings hub** — non-admin (Administration section hidden) | same (role-gated) |
| 3 | **Theme picker** bottom sheet | same (`showModalBottomSheet` + `RadioListTile`) |
| 4 | **Manage Lists** — one tile per category kind | `category_settings_screen.dart` |
| 5 | **Category editor** — per-kind CRUD list + FAB | `category_editor_screen.dart` |
| 6 | **Edit form dialog** (category / mechanic) | same (`AlertDialog` + `SwitchListTile`) |
| 7 | **Cost Code Settings** — mapping / special / test / reset | `cost_code_settings_screen.dart` |
| 8 | **Mechanics editor** — CRUD list + FAB | `mechanic_editor_screen.dart` |
| 9 | **About** — hero + info cards | `about_screen.dart` |
| — | Shared row tile / switch tile | `widgets/settings/settings_tile.dart` (`SettingsTile`, `SettingsSwitchTile`) |
| — | Cost-code grid editor | `widgets/settings/cost_code_editor.dart` |
| — | Password confirm dialog | `presentation/shared/widgets/common/password_dialog.dart` |

Hub reachable by all roles. **Administration section + all four admin sub-screens are admin-only.**

## Current state — what's not migrated

Raw Material everywhere. The hub stacks `_SectionHeader` (uppercase) + grouped `Card`s of `ListTile`s split by
indented `Divider`s, with a profile hero (`CircleAvatar` + role pill). Sub-screens use **outlined, elevation-0
`Card`** rows (not the hub's elevated grouping), `FloatingActionButton.extended` Add, `AlertDialog` forms with a
native `Switch`, and a `showModalBottomSheet` theme picker. Cupertino icons throughout (`back`, `chevron_right`,
`pencil`, `archivebox`, `arrow_clockwise`, `tag`, `wrench`, etc.). **No `AppCard`, no Lucide, no soft shadow.**
Theme already reads `AppColors` hairline/surface-muted in a couple of spots (cost-code chips) but the surfaces
are still Material `Card`. This bundle = Cupertino→Lucide + Material `Card`/`ListTile`→soft-shadow `AppCard`
rows, with dark parity.

## States & rules to preserve (don't design these away)

- **Role gating (critical):** the **Administration** section — *User Management, Activity Logs, Cost Code
  Settings, Manage Lists, Mechanics* — renders **only when `currentUser.role == admin`**. *My Profile* and
  *General* show for every role (frame 2). The four admin sub-screens are admin-only entry points.
- **Profile hero + role pill:** avatar glyph + tinted ring, display name, email, and a role badge. Colors
  **today** = admin **red**, staff **blue**, cashier **green** (`_ProfileHero._roleColor`). ⚠️ The redesign spec
  proposes **admin = purple `#9C27B0`** — confirm which wins; keep neutral discipline (color = role semantics only).
- **My Profile rows:** *Display Name* → `AlertDialog` text edit (≥2 chars); *Change Password* → `AlertDialog`
  with current / new / confirm (new ≥6 chars, must match), shows success/error snackbars.
- **Theme tile + picker:** trailing label reflects current mode (System / Light / Dark); tapping opens a
  bottom-sheet `RadioGroup` of the three modes; selecting one sets `themeModeProvider` and pops.
- **General extras:** *Store Information* is a **`// TODO` no-op** today; *About* hub row launches the native
  `showAboutDialog` (separate from the standalone `AboutScreen`, frame 9). Subtitle shows the app version.
- **Manage Lists:** one tile per `CategoryKind` — Product / Expense / Unit / Void Reason — each with its own
  icon + "Used in …" subtitle, pushing the per-kind editor.
- **Category / Mechanic editor (CRUD):** outlined rows; **inactive items stay** (name struck-through + grey +
  "Inactive" subtitle) so admin can **reactivate** — deactivate never deletes (historical records keep matching
  / snapshotted names). Trailing **Edit** (pencil) + **Deactivate (archive) / Reactivate (rotate)** icon
  buttons; tapping the row also edits. **FAB "Add"**. Category editor has a **"Seed default …" overflow** action
  for kinds with a starter set (expense / unit / void-reason; product has none). Empty state = kind glyph +
  "No {plural} yet" + "Tap Add to create one." Form dialog validates name (≥2 chars) and, when editing, shows an
  **Active** `SwitchListTile`.
- **Cost Code Settings (password-gated):** info card, digit→letter mapping (display vs `CostCodeEditor` when
  editing), special codes (00 / 000), a **Test Encoding** preview, and **Reset to Default**. **Saving and
  resetting both require `PasswordDialog` verification** and **log activity** (`logCostCodeChanged`); Reset also
  shows a confirm `AlertDialog` first. Edit toggles a bottom Save bar; Cancel discards. Mono font on codes;
  encoded test chips use **success** green outline.
- Currency grouped `₱1,234`. Snackbars: success / error throughout.
- **No sign-out** lives in Settings today (it is elsewhere) — don't invent one here unless asked.

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–07: soft-shadow
`AppCard` rows, Lucide icons (`edit` = square-pen, `archive`, `rotate-ccw`, `chevron-right`, `wrench`, `tag`,
`package`, `circle-dollar-sign`, `ruler`, `x-circle`, `info`, `code`, `shopping-cart`), theme-aware colors with
**dark parity** (canvas `#0C1415`, card `#18262A`, gold primary), and **neutral-by-default** discipline — color
only for status / role semantics. Grouped hub cards and outlined editor rows should converge on one `AppCard`
language. Keep the app bar flat on canvas. Reuse the redesigned password dialog / form-dialog styling from
earlier bundles for the cost-code and CRUD flows.
