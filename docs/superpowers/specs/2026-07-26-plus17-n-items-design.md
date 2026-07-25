# +17 N-items — five small mobile changes

Approved 2026-07-25/26 (per-item decisions via Q&A). Branch `feat/plus17-n-items`, rides in +17.

## N1 — Mono Series No in the New Job Order modal
`lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart`: the series/JO
number text renders with `AppTextStyles.monoFontFamily` (canonical token,
`app_text_styles.dart:22`), matching every other identifier surface.

## N2 — Sale Details combined mechanic·model row
`sale_detail_screen.dart`: one muted secondary row under the sale header —
`"{mechanicName} · {motorcycleModel}"`. Only when at least one is present; a
single value renders alone (no dangling separator). No row when both absent.

## N3 — Cashier expenses scoped to today
`expenses_screen.dart`: for cashiers only — (a) Week-to-date and Month-to-date
summary cards hidden (Today card remains); (b) the history list shows only
today's expenses. Staff/admin unchanged. Client-side view policy (no rules
change; cashiers still read expenses for EOD).

## N4 — EOD closing history entry on the Reports hub
`reports_hub_screen.dart`: new tile navigating to the existing
`/reports/end-of-day/history` route. No guard change: every role already holds
`viewEndOfDay` (the existing gate on that route), so "all roles" is satisfied
by the tile alone. The history screen stays read-only.

## N7 — Required description for the "Charge Item" fee
- `FeeLineEntity` gains optional `String? description` (entity + every
  serialization site: sale model, draft/JO converters; old docs → null).
- At every UI site that creates a fee line (grep `FeeLineEntity(` in
  lib/presentation — POS fee sheet + JO/draft fee entry): when the chosen fee's
  name is exactly `Charge Item`, a description field appears and is REQUIRED —
  the add is blocked with a validation message until non-empty. Other fees: no
  field.
- Display as `Charge Item — {description}` wherever fee lines are itemized:
  cart line, receipt widget, sale detail. (EOD shows only the fees total today —
  no itemization exists, so no EOD change.)
- Mobile only; web feeLines parity is a separate pending follow-up.

## Verification
TDD per item; per-item commits; full `flutter test` + `flutter analyze` before
merging to local main. No rules/index changes anywhere in this batch.
