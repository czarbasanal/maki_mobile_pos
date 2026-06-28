# Void Requests Redesign (Bundle 07) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Migrate the admin Void Requests queue + resolve sheet + approve/reject dialogs onto the elevated theme — `AppCard` rows, Lucide, **status color semantics** (pending amber / approved green / rejected red), Sale-Detail-style receipt — pixel-faithful to the 07 hand-off, behavior-preserving (mark-all-read, unread dot, tap-to-resolve, password/reason gates, admin-only).

**Architecture:** Restyle one screen file (`void_requests_screen.dart`). New pure `VoidStatusStyle` helper centralizes the per-status icon/tint/text mapping (rows, pills, count caption), reused + unit-tested. The resolve sheet's receipt is rebuilt inline to match the shipped Sale Detail (replacing the old `ReceiptWidget` usage). Dialogs restyled inline per the hifi spec. (The later modals-sync bundle will reconcile sheet/dialogs onto shared shells.)

**Tech Stack:** Flutter, Riverpod, `lucide_icons ^0.257.0`, bundled Figtree + RobotoMono, `flutter_test`.

## Global Constraints
- **Source of truth:** `design/design_handoff_void_requests/MAKI POS Void Requests.dc.html` (HTML wins over README). Match light + dark pixel-for-pixel.
- Reuse `lib/core/theme/` tokens + `AppCard`; component-specific literal radii (11, 15, 16, 26) + the prototype's status literals (e.g. pending text `#C8881A`) allowed inline (encapsulated in the helper).
- **`AppCard`** rows (no Material `ListTile`/`Divider`); **Lucide** everywhere (off Cupertino); admin-only gating unchanged.
- **Status semantics (the headline):** pending amber (`clock`), approved green (square `check-circle-2` / pill `check`), rejected red (square `x-circle` / pill `x`), with dark parity (`*OnDark`).
- `theme.colorScheme.primary` (slate→gold) for Mark-all-read, sheet Approve button, receipt sale-number + qty chips, password focus.
- Sale number = `fontFamily: 'RobotoMono'`; currency `₱1,234.00` via `.toCurrency()`; dates `MMM d, h:mm a`.
- App bar flat. Preserve EXACT behavior: newest-first; tap marks read; sheet opens only for `pending`; Mark-all-read clears all dots (disabled when none unread); Approve→password dialog; Reject→reason dialog; success/error snackbars.
- Verify each task: `flutter test` (changed) + `flutter analyze` clean.

## File Structure
| File | Responsibility | Action |
|---|---|---|
| `lib/presentation/mobile/widgets/sales/void_status_style.dart` | Pure `VoidRequestStatus` → {squareIcon, pillIcon, iconColor, textColor, tint, label} per theme | Create |
| `lib/presentation/mobile/screens/sales/void_requests_screen.dart` | List rows + count caption + resolve sheet + dialogs restyle | Modify |
| `test/presentation/widgets/void_status_style_test.dart` | Helper unit tests | Create |
| `test/presentation/widgets/void_requests_screen_test.dart` | List: status pills, count caption, unread dot, mark-all-read, tap-opens-sheet-only-pending | Create |

---

## Task 0: Branch
- [ ] `git checkout -b feat/void-requests-redesign-07` (done at execution).

## Task 1: VoidStatusStyle helper (TDD)
**Files:** Create helper + test.
**Produces:** `VoidStatusStyle.of(VoidRequestStatus, {required bool dark}) → {IconData squareIcon, IconData pillIcon, Color iconColor, Color textColor, Color tint, String label}`.

Values (ARGB):
| status | squareIcon / pillIcon | iconColor L/D | textColor L/D | tint L/D | label |
|---|---|---|---|---|---|
| pending | `clock` / `clock` | `0xFFC8881A` / `0xFFF5B547` | `0xFFC8881A` / `0xFFF5B547` | `0x1FF57C00` / `0x24F5B547` | Pending |
| approved | `checkCircle2` / `check` | `0xFF2E7D32` / `0xFF5FC86A` | `0xFF2E7D32` / `0xFF8FE39A` | `0xFFE8F5E9` / `0x294CAF50` | Approved |
| rejected | `xCircle` / `x` | `0xFFF44336` / `0xFFFF6B5E` | `0xFFF44336` / `0xFFFF6B5E` | `0x1AF44336` / `0x24FF6B5E` | Rejected |

- [ ] **Step 1: failing test** — assert icons (pending→clock both; approved square=checkCircle2 pill=check; rejected square=xCircle pill=x), label strings, and that `iconColor`/`textColor` flip by theme (approved dark iconColor `0xFF5FC86A` ≠ textColor `0xFF8FE39A`).
- [ ] **Step 2: run → FAIL.**
- [ ] **Step 3: implement** `void_status_style.dart` (switch on status).
- [ ] **Step 4: run → PASS.**
- [ ] **Step 5: commit** `feat(void): status style helper (pending/approved/rejected, dark parity)`.

## Task 2: List screen restyle + widget test (TDD)
**Design (HTML 47–99):** appbar `chevronLeft` + "Void Requests" + trailing **Mark all read** (`checkCheck` + label; primary, **muted `#B7BDC0`/`#4A5A5E` + disabled when unread count == 0**). Body padding `12,16,20`. **Count caption:** amber "N pending" pill (12/700, `VoidStatusStyle` pending tint/text) + "· N total" muted. **Rows** (newest first), each `AppCard(radius 16, margin-bottom 10, padding 14)`, `Row(crossAxisStart, gap 12)`:
- leading 40×40 radius-11 status-tint square + 20px status `squareIcon` (stroke ~1.9, `iconColor`).
- middle: top `Row` = sale number (mono 13/600) + `Spacer`/`margin-left:auto` grand total (13.5/700); subtitle (12.5 muted, mt4) `{requestedByName} · {reason}`; meta `Row` (mt7) = status pill (`VoidStatusStyle`: tint bg, `pillIcon` 11px + `label`, 10/600 ls.3, radius 999, pad 2×8) + date (11.5 hint, `MMM d, h:mm a`).
- trailing: 9px red dot (`error`/`errorOnDark`) **only when `!read`**, top-aligned.

Tap row → `markRead(id)`; if `isPending` → open resolve sheet (Task 3). Keep `voidRequestsProvider` / `voidRequestOperationsProvider` / `unreadVoidRequestCountProvider`. Empty state (HTML 102–117): 80px circle (`0x0F283E46`/`0x0DFFFFFF`) + `bell` 34px hint + "No void requests" 16/700 + sub.

- [ ] **Step 1: failing widget test** (`void_requests_screen_test.dart`): override `voidRequestsProvider` with 2 pending (unread) + 1 approved + 1 rejected; assert `find.byType(AppCard)` >= 4, `find.text('Pending')`/`'Approved'`/`'Rejected'` present, count caption `find.textContaining('pending')`, unread dots = 2 (find by a keyed/sized container — assert `find.text('Mark all read')` present). Mirror an existing screen test's `ProviderScope` override style (grep `voidRequestsProvider`). Also a test: empty list → "No void requests".
- [ ] **Step 2: run → FAIL.**
- [ ] **Step 3: implement** the list + appbar + count caption + rows + empty state (Lucide, AppCard, VoidStatusStyle). Replace `_paymentIcon`-style Cupertino with Lucide; keep nav + provider calls.
- [ ] **Step 4: run → PASS** + analyze clean.
- [ ] **Step 5: commit** `feat(void): list → AppCard rows, status semantics, count caption (07)`.

## Task 3: Resolve bottom sheet restyle
**Design (HTML 120–158):** `showModalBottomSheet(isScrollControlled, useSafeArea, backgroundColor transparent)` → a `DraggableScrollableSheet`(initial ~.9) or fixed sheet with top inset; surface `AppCard`-like (white/darkCard+hairline), radius 26 top, shadow `0 -10px 36px …`, grab handle 38×4. Regions:
1. context header (pad `12 18 14`): amber `clock` square + "Void this sale?" 18/700 + "Requested by **{name}**" 12.5; reason callout = amber-tint panel (radius 12, pad 10×12) `messageSquareQuote` + "**Reason** · {reason}".
2. receipt (scrolls, top hairline) — watch `saleByIdProvider(r.saleId)`; centered sale number (mono 13/600 primary) + `MMM d, y · h:mm a · {cashier}`; inset block (`lightSurfaceMuted`/`darkCanvas`, radius 16, hairline) of item rows: qty chip `×{qty}` (primary bg / onPrimary text; radius 7) + name 13.5/600 + `{sku} · {unitPrice}/pc` 12 muted + line net (`calculateNetAmount(isPercentage: sale.isPercentageDiscount)`) 13.5/700; labor rows: "Labor" text chip (primary-tint) + `line.description` + `sale.mechanicName ?? 'Labor'` + `line.fee`; then "Total to void" 14/600 + `sale.grandTotal` 18/700.
3. footer (top hairline, pad `14 18 20`): Reject (outlined 1.5px error, `x` icon) + Approve (filled primary, `check` icon) — equal 50px, radius 15.

Keep: Reject→`_reject` dialog, Approve→`_approve` dialog (Task 4), `Navigator.pop` then open dialog.

- [ ] **Step 1: implement** the sheet (rebuild receipt inline; drop `ReceiptWidget` import if now unused). 
- [ ] **Step 2: analyze** clean (+ existing tests green).
- [ ] **Step 3: commit** `style(void): resolve sheet → Sale-Detail receipt + reason callout (07)`.

## Task 4: Approve / Reject dialogs restyle
**Design (HTML 160–185):** `AlertDialog`-style (radius 24, surface white/darkCard+hairline). Both: header = 40×40 radius-11 tinted icon square + title 17/700 + sub 12.5 muted; labeled field; right-aligned Cancel (muted text) + filled action.
- **Approve:** green `shieldCheck` square; "Approve void" / "Confirm with your admin password"; obscured Password field (`lock` prefix + `eyeOff` toggle; focused = 1.5px primary + ring); action **Approve** filled green (`#4CAF50`/`#5FC86A`). Keep password capture + `approve(request, password)` + snackbars.
- **Reject:** error `xCircle` square; "Reject request" / "Tell the cashier why"; Reason textarea (min-h 64, "Add a short reason…"); action **Reject** filled error. Keep `reject(request, rejectionReason)` + snackbars.

- [ ] **Step 1: implement** both dialogs (Lucide, themed). Keep controllers + provider calls + `context.mounted` guards + snackbars.
- [ ] **Step 2: analyze** clean.
- [ ] **Step 3: commit** `style(void): approve/reject dialogs → themed password + reason (07)`.

## Task 5: Full verification
- [ ] `flutter analyze` → clean; `grep -rn CupertinoIcons lib/presentation/mobile/screens/sales/void_requests_screen.dart` → none.
- [ ] `flutter test` → all green (≥760 + new).
- [ ] `/code-review`; address findings.
- [ ] `/verify` — device smoke (4 states, light+dark) = user's gate.
- [ ] Finish branch; update ROADMAP (07 done) + memory; restore the modals-sync-after-07 sequencing note.

## Notes
- `VoidStatusStyle` centralizes all status coloring — never hand-roll per site.
- Receipt math mirrors Sale Detail exactly (net per line via `calculateNetAmount`, total = `grandTotal`) — restyle only, no figure changes.
- Reuse `AppColors.hairline(dark)` for dividers/borders; `AppColors.successText(dark)` etc. where applicable.
