# Modals & Bottom-Sheets Sync — Foundation + Central Wiring

> REQUIRED SUB-SKILL: superpowers:executing-plans. Scope (user-chosen): build the two shared shells + 8 variants + central wiring NOW; migrate the ~32 inline `AlertDialog` sites + 8 sheet sites in a follow-up pass.

**Goal:** One dialog shell + one bottom-sheet shell on the elevated theme (Lucide, AppColors semantics, dark parity, gold-in-dark), from which all overlay variants are composed; wire the central pieces (showConfirmDialog, both password dialogs, error dialog, success dialog, snackbars) onto them.

**Source of truth:** `/Users/czar/Desktop/easybet_intadmin/app/design/design_handoff_modals/MAKI POS Modals & Sheets.dc.html` (+ README). HTML wins. Both light + dark.

## Global constraints
- Container radius **24** (decided); button/field **16**; inset/item card **14**; summary card **16**; qty chip **8**; leading-glyph chip **13**; grab handle/pill **999**.
- Surface: light `#FFFFFF` + shadow `0 26px 60px -18px rgba(17,28,29,.42),0 6px 16px rgba(17,28,29,.07)`; dark `#18262A` + 1px `#243234` + shadow `0 26px 70px -18px rgba(0,0,0,.78)`. Sheet shadow `0 -10px 34px rgba(17,28,29,.16)` / dark `…rgba(0,0,0,.5)`.
- Scrim: light `rgba(17,28,29,.32)` / dark `rgba(0,0,0,.60)`.
- Primary filled: slate `#283E46`/white (light), gold `#E8B84C`/`#121C1D` (dark) — `theme.colorScheme.primary`/`onPrimary`; shadow `0 8px 18px -7px` of primary. Destructive primary = `AppColors.error`.
- Leading glyph chip 42×42 r13: neutral `rgba(40,62,70,.09)`+slate / dark `rgba(232,184,76,.16)`+gold; destructive red; success green; error red.
- Action row: Cancel (text, left) + Primary (filled, right); never two filled.
- Lucide stroke 1.75; Figtree; Roboto Mono for currency/SKU/sale#.
- Reuse `lib/core/theme/` tokens + `AppCard` patterns; `AppColors.hairline(dark)`. No new theme tokens.
- Verify each task: `flutter test` (changed) + `flutter analyze` clean.

## Files
| File | Action |
|---|---|
| `lib/presentation/shared/widgets/common/app_dialog.dart` | Create — `AppDialog` shell + `showAppConfirmDialog`/`showAppErrorDialog` (+ destructive flag) |
| `lib/presentation/shared/widgets/common/app_password_dialog.dart` | Create — unified password/input variant on shell (onVerify + optional audit + optional lockout) |
| `lib/presentation/shared/widgets/common/app_bottom_sheet.dart` | Create — `AppBottomSheet` shell + `showAppActionSheet` (action-list/radio) + form/scrollable helpers |
| `lib/presentation/shared/widgets/common/error_dialog.dart` | Implement (was empty) — `showErrorDialog` via shell |
| `lib/presentation/shared/widgets/common/password_dialog.dart` | `PasswordDialog.show` delegates to unified (keep signature + 3-attempt lockout) |
| `lib/presentation/shared/widgets/auth/password_confirm_dialog.dart` | `PasswordConfirmDialog.show` delegates to unified (keep signature + ActivityLogger audit) |
| `lib/presentation/mobile/widgets/pos/checkout_success_dialog.dart` | Refactor onto shell (success variant + elastic scale-in) |
| `lib/core/extensions/navigation_extensions.dart` | `showConfirmDialog` → shell; snackbars → Lucide + dark parity |
| `lib/presentation/shared/widgets/common/common_widgets.dart` | Export new shells |
| tests: `app_dialog_test`, `app_bottom_sheet_test`, `app_password_dialog_test` | Create |

## Tasks
1. **AppDialog shell + confirm/error variants (TDD).** `AppDialog({leadingIcon, leadingColor, leadingTint, title, onClose, content, primaryLabel, primaryColor, onPrimary, cancelLabel, destructive})`. Helpers: `showAppConfirmDialog(...)→Future<bool>` (neutral slate / destructive red + `alertTriangle` warning line); `showAppErrorDialog(...)→Future<void>` (`alertCircle` red chip, single OK). Test: confirm primary→true, cancel→false, barrier→false; destructive shows warning + red; error OK pops.
2. **Unified password dialog (TDD).** `showAppPasswordDialog(context,{title, subtitle, confirmLabel, onVerify:Future<bool>Function(String), maxAttempts?, infoNote})→Future<bool>`. Shell + labeled field (`lock` prefix, `eyeOff` toggle, focus ring 1.5px primary + `0 0 0 4px` tint), optional info notice, optional lockout. Test: obscure default, toggle, lockout after maxAttempts disables, verify→true.
3. **Wire password_dialog + password_confirm_dialog** to delegate to #2 (keep `.show` signatures; lockout in PasswordDialog path; audit via authActions+ActivityLogger in PasswordConfirmDialog path). Existing callers unchanged.
4. **error_dialog.dart** implement `showErrorDialog(context,{title,message})` → `showAppErrorDialog`. Export.
5. **AppBottomSheet shell + action/radio (TDD).** `AppBottomSheet({leadingIcon,title,subtitle,onClose,body,footer})` (grab handle 40×4, header, scroll body, pinned SafeArea+keyboard-aware footer, top radius 24). `showAppActionSheet(context,{title?, actions:List<AppSheetAction(icon,label,onTap,selected?)>})`. Test: rows render + tap invokes.
6. **checkout_success_dialog** refactor onto AppDialog success content + elastic scale-in (`successPop`/`successCheck`); keep public API + existing test green.
7. **navigation_extensions:** `showConfirmDialog`→`showAppConfirmDialog`; snackbars→Lucide (`checkCircle2`/`alertTriangle`/`alertCircle`, close `x`) + dark-parity fills/text. Keep signatures.
8. **common_widgets** exports; **full verify** (analyze + `flutter test`), `/code-review`, `/verify`, finish branch. Update ROADMAP + memory. (Migration of 32 inline sites = tracked follow-up.)

## Notes
- Keep `showConfirmDialog`/`showSuccessSnackBar` etc. signatures stable so the 32 follow-up sites migrate incrementally.
- Success animation: card scale .86→1.04→1, check .5→1.14→1, ~550ms elastic (`Curves.elasticOut`-ish via TweenSequence or scale transition).
- Snackbars remain a separate channel (not folded into shells), just visually rhyming.
