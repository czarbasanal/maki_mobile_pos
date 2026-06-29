# Handoff: MAKI POS — Settings 10a (hub · theme picker · about)

> # ⚠️ CLAUDE CODE — COPY EVERY DETAIL IN THIS HANDOFF. NO EXCEPTIONS.
> **`MAKI POS Settings 10a.dc.html` is the single source of truth. Reproduce it EXACTLY.**
> Every color, hex, font size, weight, padding, gap, radius, border, shadow, icon, copy string, row order, and
> state below is **intentional and already verified** — replicate all of it. **Do NOT** redesign, "improve",
> simplify, round values, substitute icons, re-order sections, rename labels, or drop any state. Build **both light
> and dark**, every screen, every state shown.
> - If this README and the HTML ever disagree, **the HTML wins** — open it and read the inline styles directly.
> - Implement in the existing Flutter codebase using its real widgets/theme (this is a visual spec, not code to paste).
>
> ## 🛑 IF ANYTHING IS UNCLEAR, STOP AND ASK THE USER TO CONFIRM.
> **Do not guess, do not improvise, do not fill gaps with your own judgment.** If a value, behavior, mapping,
> permission rule, edge case, or anything else here is ambiguous, missing, or seems to conflict with the existing
> codebase — **pause and ask the user a direct question before writing code.** A wrong assumption is more expensive
> than a question. When in doubt, match the prototype exactly; when the prototype itself doesn't answer it, **ask**.

## Overview
Bundle **10** of the MAKI POS redesign is the largest, split into two slices. **This is 10a** — the **Settings
hub** (admin + role-gated non-admin), the **theme picker** bottom sheet, and the standalone **About** screen.
(Slice **10b** covers the four admin editors — Manage Lists, Category editor + form dialog, Cost Code Settings,
Mechanics.) This migrates raw Material onto the elevated global theme (bundles 01–09): grouped
`Card`+`ListTile`+`Divider` sections become **soft-shadow grouped `AppCard`s** with inset hairlines; the profile
hero keeps its avatar + **role pill**; the native `Switch`/`RadioListTile` get themed treatments; **every Cupertino
glyph → Lucide**. Full **dark parity (gold leads in dark)**.

**Neutral-by-default discipline (MUST KEEP).** The only colors are the **slate/gold primary** (selected radio,
About brand mark; chevrons stay muted grey) and the **role pill**, which carries genuine role semantics.

### ✅ Resolved decision — role pill color
The role colors are **admin = red `#F44336`** (the team chose to **retain the red shipped today** rather than the
spec's purple proposal), **staff = blue `#2196F3`**, **cashier = green `#4CAF50`**. Keep `_ProfileHero._roleColor`
returning red for admin. (Cashier isn't shown in 10a's two frames but follows the same pattern.)

## About the Design Files
Design references created in HTML — a prototype of the intended look, **not production code to ship**. Recreate in
the Flutter codebase (`lib/presentation/mobile/screens/settings/…`, `about_screen.dart`) using its real widgets
(`SettingsTile`, `SettingsSwitchTile`, theme layer) and translate the CSS below into Flutter styles.
- `MAKI POS Settings 10a.dc.html` — the redesign prototype (4 surfaces × light + dark). **Source of truth.**
- `reference_current-ui.html` — the current pre-redesign UI (all 9 Bundle-10 frames), before/after only.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, icons are final. **Match them precisely.**

---

## Design Tokens
| Token | Light | Dark |
|---|---|---|
| Screen canvas | `#F6F5F3` | `#0C1415` |
| Grouped card (`AppCard`) | `#FFFFFF` + shadow `0 2px 8px rgba(17,28,29,.06)` | `#18262A` + 1px border `#243234` |
| Row glyph tile (neutral) | 36×36 radius 10, `rgba(40,62,70,.06)` bg · glyph `#8A9296` | `rgba(147,160,163,.12)` bg · glyph `#93A0A3` |
| Inset hairline (between rows) | `#F0F0F0`, `margin-left:62px` (past tile) | `#243234` |
| Hero divider | `#F0F0F0`, inset 16 both sides | `#243234` |
| Primary (slate) | `#283E46` | gold `#E8B84C` (selected radio, brand mark) |
| Text primary / muted | `#16201F` / `#8A9296` · chevron `#B4B8BA` | `#ECEFEF` / `#93A0A3` · chevron `#566163` |
| **Role — admin** | text/icon `#F44336` on `rgba(244,67,54,.10)` | `#FF6B5E` on `rgba(244,67,54,.22)` |
| **Role — staff** | `#2196F3` on `rgba(33,150,243,.10)` | `#7FB8F5` on `rgba(33,150,243,.22)` |
| **Role — cashier** | `#4CAF50` on `rgba(76,175,80,.10)` | `#8FE39A` on `rgba(76,175,80,.20)` |
| About brand-mark tile | 74×74 radius 20, `rgba(40,62,70,.07)` · icon `#283E46` | `rgba(232,184,76,.14)` · icon `#E8B84C` |

### Typography (Figtree; mono only for codes, none here)
App-bar title 18/600 · section label **11/600 uppercase, letter-spacing .8, muted** · row title 15/600 · row
subtitle 12.5 muted · hero name 17/600 · hero email 12.5 muted · role pill 11/700 (padding 3×11, radius 999) ·
sheet title 16/700 · radio label 15 (selected 15/600) · About app name 22/700 · version 13 muted / build 12 hint ·
About card heading 14/700 · body 13/1.55 · feature title 13.5/600 + sub 12 · info row label 13 muted + value 13/600.

**Radii:** group card / sheet brand area 16 · row glyph tile 10 · About brand-mark 20 · sheet top 24 · phone frame 42.

### Icons — Lucide (stroke 1.75–1.95)
back `chevron-left` · row chevron `chevron-right` (muted) · My Profile `user` / `lock` · admin hero `shield-half` ·
staff/cashier hero `user-round` · Administration `users` / `clock` / `code` / `tag` / `wrench` · General `sun`
(Theme — `moon` when the current mode is Dark) / `store` / `info` · theme picker `monitor` (System) / `sun` (Light)
/ `moon` (Dark) · About brand `shopping-cart`, features `shopping-cart` / `package` / `briefcase` / `bar-chart-3` ·
non-admin spec-note `shield-off`.

---

## Screens / Views

### 1 — Settings hub (admin)  (`settings_screen.dart`)
App bar: `chevron-left` + **"Settings"** (no trailing). Three sections, each = an **uppercase section label** above
a **grouped `AppCard`** (rows split by inset hairlines):
- **My Profile** — a **profile hero** (avatar 54×54 round, role-tinted bg + role glyph; name; email; **role pill**),
  a hero divider, then rows **Display Name** (`user`, subtitle = current name) and **Change Password** (`lock`,
  "Update your login password").
- **Administration** *(admin only)* — **User Management** (`users`) · **Activity Logs** (`clock`) · **Cost Code
  Settings** (`code`) · **Manage Lists** (`tag`) · **Mechanics** (`wrench`), each subtitle + `chevron-right`.
- **General** — **Theme** (`sun`, subtitle = current mode label "Light"/"Dark"/"System") · **Store Information**
  (`store`, "Business name and details") · **About** (`info`, "App version 1.0.0").

### 2 — Settings hub (non-admin)  (role-gated)
Identical chrome; role = **staff** (blue hero + pill). **The entire Administration section is absent.** My Profile +
General only. *(The dashed "Spec note" block in the prototype is a **handoff annotation, not real UI** — do not
build it; it documents that Administration is hidden for non-admins.)*

### 3 — Theme picker  (`showModalBottomSheet` + `RadioGroup`)
Scrim over the dimmed hub; rounded-top sheet. Grab handle, **"Theme"** title (16/700), then three radio rows:
**System default** (`monitor`) · **Light** (`sun`) · **Dark** (`moon`). Each = leading glyph + label + a radio dot
(right); the **selected** dot is filled slate/gold, others are a 2px muted ring. Selecting one sets
`themeModeProvider` and pops. *(Prototype shows Light selected in the light frame, Dark selected in the dark frame.)*

### 9 — About  (`about_screen.dart`)
App bar: `chevron-left` + **"About"**. Centered **brand mark** (slate/gold-tinted rounded tile + `shopping-cart`),
**"MAKI Mobile POS"** (22/700), **"Version 1.0.0"**, **"Build 2"**. Then cards: **About This App** (paragraph);
**Key Features** (4 rows: Point of Sale / Inventory Management / Supplier Management / Reports & Analytics, each a
neutral glyph tile + title + sub); **Technical Information** (Platform Flutter · Backend Firebase · Currency
Philippine Peso (₱) · Barcode Code 128). Footer **"© 2026 All rights reserved"** (centered muted).

---

## Interactions & rules (must keep)
- **Role gating (critical):** the **Administration** section renders **only when `currentUser.role == admin`**. My
  Profile + General show for every role. (Its five rows are the entry points to the 10b admin sub-screens.)
- **Profile hero role pill:** admin **red `#F44336`** / staff blue / cashier green (color = role semantics only).
- **Display Name** → `AlertDialog` text edit (≥2 chars). **Change Password** → `AlertDialog` (current / new / confirm;
  new ≥6 chars, must match); success/error snackbars.
- **Theme tile** subtitle reflects the current mode; tapping opens the picker; selecting sets the provider and pops.
- **Store Information** is a **`// TODO` no-op today** (keep the row; wire nothing new unless asked). The hub's
  **About** row launches the native `showAboutDialog` — **separate** from this standalone `AboutScreen`; keep both.
- **No sign-out** lives in Settings — don't invent one.
- **Theme toggle** swaps the full light/dark token set (primary slate → gold; the Theme row glyph shows `moon` in dark).

## Must-keep (don't design these away)
Role gating + the three role-pill colors (admin red) · grouped `AppCard` sections with inset hairlines · the
profile hero · the Theme-subtitle reflecting current mode · the picker's three modes with a single filled selection ·
the About brand mark + three info cards · **dark parity** on all four surfaces · **Lucide** (off Cupertino) ·
neutral-by-default (chevrons muted; color only for primary + role pill).

## Assets
Icons: **Lucide** (`lucide_icons`). Fonts: **Figtree** (Roboto Mono present project-wide but unused on these
surfaces). No imagery.

## Files
- `MAKI POS Settings 10a.dc.html` — redesign prototype, **source of truth** (4 surfaces × light/dark).
- `reference_current-ui.html` — current/raw-Material UI (all 9 Bundle-10 frames), before/after only.
