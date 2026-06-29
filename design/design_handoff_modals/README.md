# Handoff: MAKI POS — Modals & Bottom Sheets (cross-cutting)

> # ⚠️ CLAUDE CODE — COPY EVERY DETAIL IN THIS HANDOFF. NO EXCEPTIONS.
> **`MAKI POS Modals & Sheets.dc.html` is the single source of truth. Reproduce it EXACTLY.**
> Every color, hex, font size, weight, padding, gap, radius, border, shadow, icon, and copy string below is
> **intentional and already verified** — replicate all of it. **Do NOT** redesign, "improve", simplify, round
> values, substitute icons, or rename. Build **both light and dark** themes.
> - If this README and the HTML ever disagree, **the HTML wins** — open it and read the inline styles directly.
> - This is a **synchronization spec**, not code to paste: implement as **two reusable shells** in the existing
>   codebase, then route every existing dialog/sheet through them.
> - **This bundle ships both shells + the full variant set** (5 dialog variants, 3 sheet variants), each in
>   light + dark. Build the two shells first as shared widgets, then route every call site through the variants
>   under **Variants** — variants only fill the shells' slots, with no per-site styling.

## Overview
This is the **cross-cutting** bundle of the MAKI POS redesign — not a screen, but the **one modal + bottom-sheet
language** every overlay in the app adopts. Today these surfaces are a patchwork: raw `AlertDialog`s (theme radius
24) sit next to custom `Dialog`s that pin their own radii/colors; every bottom sheet hand-rolls its own grab handle,
padding and footer (**≥3 different grab-handle implementations**); icons are mostly Cupertino (only
`checkout_success_dialog` migrated to Lucide); there is **no shared confirm/destructive/input component**; and the
password dialog exists **twice**. The fix is **one dialog shell + one bottom-sheet shell**, both on the **elevated
global theme** (soft-shadow surfaces, Lucide, `AppColors` status semantics) with **full dark parity (gold leads in
dark)**, from which a small set of variants is composed.

This reuses the **global theme** — do **not** invent new tokens. Pull from `design/handoff/maki-theme/` /
`lib/core/theme/` exactly as bundles 01–07 did. **Radius decision (the README's open question): KEEP `xl = 24`**
for both shell containers.

## About the Design Files
These files are **design references created in HTML** — a prototype of the intended look, **not production code to
ship**. The task is to **recreate them in the existing Flutter codebase** as two shared widgets and wire the
existing call sites to them. Translate the CSS values below into Flutter `ThemeData` (`dialogTheme` ~L259 light /
~L597 dark, `bottomSheetTheme` adjacent in `lib/core/theme/app_theme.dart`) + two shell widgets.

- `MAKI POS Modals & Sheets.dc.html` — the redesign prototype: both shells × light + dark, a shell-token strip, and
  an anatomy panel per shell. **Source of truth.**
- `reference_current-ui.html` — the current overlay surfaces grouped by archetype (the patchwork), for before/after
  and to see every call site the shells must absorb.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, and icons are final. **Match them precisely.**

---

## Source files (what to migrate onto the shells)
| Archetype | Source widget(s) | Target |
|---|---|---|
| 2-action confirm (neutral) | `core/extensions/navigation_extensions.dart` → `showConfirmDialog` + **~20 inline `AlertDialog`s** | **Dialog shell** |
| Destructive confirm | `mobile/widgets/pos/void_sale_dialog.dart`, `request_void_dialog.dart`, delete-* confirms | Dialog shell · destructive |
| Single-input / password | `shared/widgets/common/discount_input_dialog.dart`, `password_dialog.dart` **+** `auth/password_confirm_dialog.dart` | Dialog shell · input (absorb **both** password dialogs) |
| Error | inline banners + `showErrorSnackBar`; `shared/widgets/common/error_dialog.dart` is an **empty file** | Dialog shell · error (replace empty file) |
| Success | `mobile/widgets/pos/checkout_success_dialog.dart` (already Lucide, elastic scale-in) | Dialog shell · success |
| Action-list / radio picker | `inventory/product_image_uploader.dart`, settings `_showThemePicker` | **Sheet shell** · action/radio |
| Draggable scrollable + footer | `drafts/draft_detail_sheet.dart`, `sales/void_requests_screen.dart` resolve sheet | **Sheet shell** (the base shown here) |
| Form sheet (keyboard-safe) | `inventory/stock_adjustment_dialog.dart` (a sheet, mis-named "dialog") | Sheet shell · form |

The **~20 inline `AlertDialog` 2-action confirms** (delete category / mechanic / expense / user / supplier · close
day · replace cart · switch discount type …) are the biggest group — they all collapse into the **one** dialog
shell.

---

## Design Tokens (shared by both shells)

| Token | Light | Dark |
|---|---|---|
| Screen canvas (behind scrim) | `#F6F5F3` | `#0C1415` |
| **Scrim** | `rgba(17,28,29,.32)` | `rgba(0,0,0,.60)` |
| Surface (dialog & sheet) | `#FFFFFF` | `#18262A` + 1px hairline `#243234` |
| Primary (filled action) | slate `#283E46`, text `#FFFFFF` | gold `#E8B84C`, text `#121C1D` **(gold leads)** |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| Body copy (dialog) | `#5A6468` (emphasis `#16201F`/600) | `#93A0A3` (emphasis `#ECEFEF`/600) |
| Hairline / divider | `#ECECEC` · divider `#F0F0F0` | `#243234` |
| Field / inset fill · border | `#FAFAFA` · `#E2E2E2` | `#121C1D` · `#2C3C3E` |
| Mono (currency · SKU · codes) | `#16201F`, Roboto Mono 500/600 | `#ECEFEF` |

**Radii (KEEP these):** dialog & sheet container **24** · button & field **16** · inset/item card **14** ·
summary card **16** · qty chip **8** · dialog leading-glyph chip **13** · grab handle / pill **999**.

**Type:** **Figtree** (400/500/600/700/800) everywhere; **Roboto Mono** (500/600) for currency, SKUs, sale numbers
only. **Icons: Lucide, stroke 1.75**, rounded caps (migrate **off Cupertino**: `lock`→`lock`, `xmark`→`x`,
`trash`→`trash-2`, `square_pencil`→`square-pen`, `cube_box`→`package`).

**Currency** grouped `₱1,234.00`. **Dates** via the app formatter (`MMM d, h:mm a`).

---

## Shell 1 — Dialog  (`showDialog` / `AlertDialog`)
Centered card over the scrim, **24px inset** from the screen edges (`alignment: center`, `insetPadding: 24`).

**Surface:** radius **24**, padding `22 22 16`.
- Light: `#FFFFFF`, shadow `0 26px 60px -18px rgba(17,28,29,.42)` + `0 6px 16px rgba(17,28,29,.07)`.
- Dark: `#18262A` + 1px `#243234`, shadow `0 26px 70px -18px rgba(0,0,0,.78)`.

**A · Header** (`display:flex; align-items:flex-start; gap:13`):
- **Leading status glyph — optional.** 42×42 chip, radius 13, Lucide glyph 22px (stroke 1.75). Tint carries
  status: neutral = `rgba(40,62,70,.09)` bg + slate `#283E46` glyph (dark `rgba(232,184,76,.16)` + gold `#E8B84C`).
  *(destructive→red, success→green, per Variants.)*
- **Title** 18/600, `#16201F`/`#ECEFEF`, `flex:1`, line-height 1.3.
- **Close — optional.** `x` 20px, `#8A9296`/`#6C797C`, 30px round hit area, top-right.

**B · Content** — body copy 14.5/1.55 `#5A6468`/`#93A0A3` (emphasis in primary text, 600); per variant this region
becomes a field, a warning banner, or a success hero.

**C · Action row** (`margin-top:22; justify-content:flex-end; gap:6`):
- **Cancel** = text (or outlined) — 14.5/600, `#8A9296`/`#93A0A3`, padding `11 16`, radius 16 — on the **left**.
- **Primary** = filled — 14.5/600, padding `12 22`, radius 16 — on the **right**. Light slate `#283E46`/white,
  shadow `0 8px 18px -7px rgba(40,62,70,.6)`; dark gold `#E8B84C`/`#121C1D`, shadow `…rgba(232,184,76,.5)`.

**Mock shown:** neutral confirm — leading `shopping-cart` chip · "Replace cart?" · "Loading this draft will replace
the **3 items** currently in your cart." · **Cancel** / **Replace**.

**Rules:** primary is **always filled and right**; never two filled buttons. Destructive variant → **red filled
primary + warning line**. Leading glyph carries the status color (slate/gold · red · green).

## Shell 2 — Bottom sheet  (`showModalBottomSheet` / `DraggableScrollableSheet`)
Pinned to the bottom over the scrim; **top corners radius 24**, flush to screen edges; `display:flex; column`.
Snap sizes **0.5 / 0.7 / 0.95** (0.7 shown). `isScrollControlled` + `useSafeArea`.
- Light: `#FFFFFF`, shadow `0 -10px 34px rgba(17,28,29,.16)`.
- Dark: `#18262A` + top 1px `#243234`, shadow `0 -10px 34px rgba(0,0,0,.5)`.

**A · Grab handle** — 40×4 pill, radius 999, `#E2E2E2`/`#2C3C3E`, margin `12 auto 6`. **One implementation,
reused everywhere** (replaces the ≥3 hand-rolled ones).

**B · Header** (`padding:8 18 14; gap:13; align-items:flex-start`): leading glyph (`file-text` 24px,
`#8A9296`/`#93A0A3`) + title 19/700 over sub 13 muted, + optional **close** (`x` 20px). Divider beneath = top
hairline of the body.

**C · Body** — **scrollable**, `padding:16 18`, top divider `#F0F0F0`/`#243234`. Grouped by **uppercase section
labels** (11/700, letter-spacing .8, muted). Content blocks shown:
- **Item row** — border 1px `#ECECEC`/`#243234`, fill `#FAFAFA`/`#121C1D`, radius 14, `padding:10 12; gap:12`:
  **qty chip** `×N` (outlined slate `#283E46` / dark gold `#E8B84C`, radius 8, 12/600 mono) + name 14/600 over
  `{SKU} · ₱{unit}/pc` (12 muted, SKU mono) + line total 14/600 mono.
- **Summary card** — radius 16, padding `12 14`; light border `#ECECEC` + shadow `0 2px 8px rgba(17,28,29,.05)`,
  dark border `#243234` + fill `#121C1D`. Rows 14 (label muted, value mono); **Total** row 700 with a top hairline.

**D · Pinned footer** (`padding:14 18 20`, top divider, `gap:12`) — respects **SafeArea** + keyboard insets:
- **Secondary** = outlined, 50px, radius 16, `#E2E2E2`/`#2C3C3E` border (icon-only here: `trash-2` 20px, muted).
- **Primary** = filled, `flex:1`, 50px, radius 16, slate/gold fill, icon (`shopping-cart` 18) + label 15/600,
  shadow as the dialog primary.

**Mock shown:** draft detail — `file-text` · "Friday afternoon" / "Fri, Jun 27, 2026 · 2:14 PM" · Items (2):
ASK Brake Shoe XRM 125 `×2` `BRK-001` ₱500.00 · NGK Spark Plug CPR6EA-9 `×1` `SPK-009` ₱200.00 · Summary: Subtotal
₱700.00 · Labor ₱280.00 · **Total ₱980.00** · footer **[trash]** / **Load into Cart**.

**Rules:** one handle / header / footer implementation, reused everywhere; footer keyboard- + SafeArea-aware; top
corners 24, flush to edges.

---

## Variants — composed FROM the two shells above
Each fills the shells' slots only — no per-site styling. All are in the prototype, light + dark.

**Dialog variants:** **1 · confirm (neutral)** — shown. **2 · destructive** — red leading chip + `alert-triangle`
warning line + **red filled** primary (`AppColors.error`); keeps "This action cannot be undone…". **3 ·
single-input / password** — labeled field in the content slot; password = obscured + `lock` + `eye-off` show/hide,
focus ring (1.5px slate/gold + `0 0 0 4px` tint); **absorbs both** `password_dialog` (3-attempt lockout) and
`password_confirm_dialog` (`ActivityLogger` audit) as options. **4 · error** — a real shared error dialog (replaces
the empty `error_dialog.dart`): `alert-circle` red chip + message + single **OK**. **5 · success** — green
`check` hero circle + change-due hero + Total/Received card + **Receipt** (outlined) / **Done** (primary filled); **elastic scale-in** ≈550ms (`Curves.elasticOut`-style; card scale .86→1.04→1, check .5→1.14→1).

**Sheet variants:** **6 · action-list / radio** — auto-height; tappable rows (icon + label), radio variant shows a
selected ring. **7 · scrollable + footer** — shown (draft / void-resolve receipt breakdown). **8 · form sheet** —
segmented control (Add/Remove/Set) + focused field + summary, **keyboard-safe**: shown above a numeric keypad with the footer pinned above the keyboard (`viewInsets` bottom inset).

## Snackbars — adjacent channel (shown, light + dark)
A transient bar **docked at the bottom** (above SafeArea), **not** a modal: 1.5px status border + **lightened fill**,
icon + text + close (×), **one at a time** (newest replaces), auto-hide ≈3.5s, radius 14. Shown over a **live,
non-dimmed** screen on purpose. `showSuccess/Warning/ErrorSnackBar` stay their own channel — never a replacement for
a confirm dialog; just make them rhyme with the shells. Tokens (light fill · light text · OnDark text):
- **success** `#E8F5E9` · `#2E7D32` · `#8FE39A`
- **warning** `#FFF4E0` · `#B5701A` (border `#F0A23C`) · `#F5B547`
- **error** `#FDECEA` · `#C62828` · `#FF6B5E`

Dark uses the status hue at ~14–16% fill on the dark surface with a ~50% border; icons `check-circle-2` / `alert-triangle` / `alert-circle` (stroke 1.9), close `x`.

## Must-keep (don't design these away)
- **Destructive stays red + explicit confirm** (`AppColors.error` primary + warning line).
- **Password-gated actions stay gated** — obscured field + show/hide; retain **both** behaviors (3-attempt lockout
  *and* `ActivityLogger` audit) as options on the single input dialog.
- **Scrollable sheets keep drag-to-resize** (0.5/0.7/0.95) **+ SafeArea pinned footers**; **form sheets stay
  keyboard-safe**.
- **Success/error feedback stays**, semantic colors intact.
- **Snackbars are adjacent, not modal** — `showSuccess/Warning/ErrorSnackBar` (outlined + lightened-fill,
  dismissible) stay a **separate** channel; do **not** fold them into the shells, just keep them visually rhyming.
- **Container radius = 24** (decided); fields 16, pills 999.

## Assets
- Icons: **Lucide** (`lucide_icons`) — migrate off Cupertino. No custom SVGs.
- Fonts: **Figtree** + **Roboto Mono** (already in project).
- No images/photography.

## Files
- `MAKI POS Modals & Sheets.dc.html` — redesign prototype, **source of truth** (both shells + all 8 variants × light/dark, anatomy panels + snackbar reference).
- `reference_current-ui.html` — current overlay patchwork grouped by archetype, before/after only.
- `support.js` — prototype runtime (Design Component host); not part of the Flutter app.
