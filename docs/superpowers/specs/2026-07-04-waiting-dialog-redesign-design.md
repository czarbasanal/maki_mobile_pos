# Waiting Dialog Redesign — Contextual Variant

**Date:** 2026-07-04
**Source:** `design/design_handoff_waiting_dialog/` (Contextual variant of `MAKI POS Waiting Dialog.dc.html`)
**Scope:** Visual replacement of `AppWaitingDialog` only. No wiring changes.

## Goal

Replace the current `AppWaitingDialog` (horizontal row: 22px spinner + text) with the
designer-approved **Contextual** waiting dialog: a centered column card with a 56px primary
progress ring, verb-first title, and optional one-line subtitle. Light + dark parity.

The dialog **composes on top of skeleton loading** (bundle's global rule): skeletons keep
covering passive reads, unchanged; the waiting dialog covers user-initiated writes and layers
above via the root-navigator modal — which is already how `runWithWaiting` works. **No skeleton
code changes.**

## Non-goals (confirmed conservative defaults — user was away; flag on review)

- **No new call sites** — SUPERSEDED after review: the user asked to include login and
  void-sale. Now wrapped: login sign-in ("Signing in…") + reset email ("Sending…", login's
  `LoadingOverlay`/`_isLoading` removed), request-void ("Submitting…"), admin approve/reject
  ("Approving…"/"Rejecting…"), admin direct void ("Voiding…", shown over the password dialog),
  dashboard sign-out ("Signing out…", dashboard's `LoadingOverlay`/`_isLoggingOut` removed).
  Checkout remains deliberately unwrapped. `LoadingOverlay` now survives only in draft-edit.
- **No Cancelable variant.** The mock shows it as an escalation for long-running cancelable
  work (e.g. sync); no such operation exists in the app today. Documented, not built (YAGNI).
- **No subtitle wired anywhere yet.** The API supports it; call sites stay title-only.
  (Bill-out — the mock's example — is synchronous today: `loadFromDraft` + navigate. Nothing
  to wait on.)

## Component design

File: `lib/presentation/shared/widgets/common/app_waiting_dialog.dart` (in-place rewrite;
widget name and `runWithWaiting` API preserved).

### Layout (per mock, pixel-faithful)

Centered column card over the standard dialog scrim:

| Element | Spec |
|---|---|
| Card | radius **24**, padding **v32 h34**, min-width **220**, max-width **300**, column, center-aligned |
| Ring | **56px** outer, **4px** stroke; faint primary full-circle track + primary quarter arc; rotates **0.8s linear** infinite |
| Title | **17 / w600**, ink, centered, **20px** below ring. Verb-first present tense (`Saving…`) — callers already comply |
| Subtitle (optional) | **13.5 / w400, height 1.5**, secondary, centered, max-width **212**, **6px** below title |

### Tokens (all existing `AppColors` / `AppDialog` constants)

| Token | Light | Dark |
|---|---|---|
| Card surface | `AppColors.lightCard` (#FFF) | `AppColors.darkCard` (#18262A) + 1px `AppColors.darkHairline` border |
| Scrim | `AppDialog.scrimColor(false)` (0x52111C1D — matches mock .32) | `AppDialog.scrimColor(true)` (0x99000000 — matches mock .6) |
| Ring arc | `AppColors.brandSlate` (#283E46) | `AppColors.primaryAccent` (#E8B84C) |
| Ring track | `Color(0x1F283E46)` (mock rgba .12) | `Color(0x2EE8B84C)` (mock rgba .18) |
| Title | `AppColors.lightText` | `AppColors.darkText` |
| Subtitle | `AppColors.lightTextMuted` (#8A9296) | `AppColors.darkTextSecondary` (#93A0A3) |

Shadow: reuse the app's dialog-level elevation (same surface language as `AppDialog`); dark
surface carries the hairline border, not a shadow — matching the theme convention.

### Spinner implementation

Flutter's stock `CircularProgressIndicator` animates arc length (grow/shrink), not the mock's
fixed quarter-arc constant-speed spin. To match the mock: a private `_WaitingRing` —
`CustomPaint` drawing the full track circle + a fixed ~90° primary arc (round caps off, 4px
stroke), wrapped in a `RotationTransition` driven by a repeating 800ms linear
`AnimationController`.

### API

```dart
context.runWithWaiting(action, message: 'Saving…');            // unchanged
context.runWithWaiting(action, message: 'Billing out…',
    subtitle: 'Loading this job order into the register.');    // new optional param
```

- `subtitle` is threaded through `runWithWaiting` → `AppWaitingDialog`; null renders nothing.
- Behavior preserved: root navigator, `barrierDismissible: false`, `PopScope(canPop: false)`,
  rethrows the action's error, callers must not navigate inside the action.

### Minimum display ~300ms (specified in the bundle's Behavior section)

`runWithWaiting` records the start time; when the action settles (success **or** error), if
elapsed < 300ms it waits the remainder before popping — the dialog never flashes on fast
calls. The action's result/error is returned/rethrown only after the pop, preserving current
caller semantics.

## Error handling

Unchanged: the helper pops the dialog in `finally` and rethrows, so every call site keeps its
existing try/catch and error UI.

## Testing (TDD)

Update `test/presentation/shared/widgets/common/app_waiting_dialog_test.dart`:

1. Renders ring + title; no subtitle widget when `subtitle` is null.
2. Renders subtitle with correct style/color when provided.
3. Light/dark token assertions (card color, border only in dark, arc color slate/gold).
4. `runWithWaiting` still: blocks back (PopScope), returns the action's value, rethrows errors,
   pops the dialog in both paths.
5. Min-display: a fast (instant) action keeps the dialog up ~300ms (`tester.pump` timing);
   a slow action closes immediately on completion.

Full `flutter test` + `flutter analyze` before done.

## Files touched

- `lib/presentation/shared/widgets/common/app_waiting_dialog.dart` — rewrite visual + subtitle + min-display.
- `test/presentation/shared/widgets/common/app_waiting_dialog_test.dart` — extend.
- No call-site edits, no skeleton edits, no theme-file edits.
