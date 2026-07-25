# Compact mechanic + motorcycle-model dropdowns

Date: 2026-07-25
Surface: Flutter mobile, styling only.

## Problem

The mechanic and motorcycle-model dropdowns (POS checkout, JO edit screen,
save/new JO dialogs) render at full field height (~56px) with 14px+ text —
oversized next to the compact card/labor/fee rows around them.

## Decision (confirmed with user)

Dense field, 13px text: `isDense` + tighter content padding (~40px closed
height), 13px text for the closed button AND the menu items, prefix icons
scaled down to match. Only these two pickers change; other dropdowns keep
the default size.

## Design

1. `AppDropdown` (`lib/presentation/shared/widgets/common/app_dropdown.dart`)
   gains `compact: bool = false`:
   - merges `isDense: true` + `contentPadding: EdgeInsets.symmetric(
     horizontal: 12, vertical: 8)` into the caller's decoration (caller's
     explicit values win if set);
   - closed-button text style 13px; menu item text defaults to 13px in
     compact mode (via a DefaultTextStyle or the internal item builder —
     whichever the widget's structure supports cleanly; callers' explicit
     item styles still win);
   - non-compact behavior byte-identical to today.
2. `MechanicPicker` and `MotorcycleModelPicker` pass `compact: true` and
   reduce their prefix `Icon` size to 18. No call-site changes anywhere
   else; all four hosting surfaces inherit the compact look.

## Not changing

Any other `AppDropdown` usage (category/kind filters, payment selectors),
dropdown behavior/API beyond the new optional flag, sentinel add-entries.

## Testing

- `AppDropdown` widget test: compact renders 13px button text + isDense
  decoration; non-compact unchanged (pin one default-size assertion).
- Picker tests: extend one test per picker asserting the rendered
  selected-value text is 13px; existing behavior tests keep passing.
