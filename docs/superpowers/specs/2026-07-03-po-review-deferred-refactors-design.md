# PO review deferred refactors — provider split · shared add sheet · segmented cleanup

_Approved 2026-07-03. Closes the three findings deferred from the PO-redesign code review
(spec `2026-07-03-purchase-orders-redesign-totals-design.md`). Read-side + presentation only —
no Firestore write path, rules, or entity schema changes._

## (a) Split coverDays out of the suggestions fetch

**Problem:** `reorderSuggestionsProvider` is an autoDispose family keyed by
`({windowDays, coverDays})`, but `coverDays` only feeds pure client math. Every settled
cover-stepper change refetches up to 10k sales and blanks the whole screen to `LoadingView`;
a 350ms debounce papers over it.

**Design:**
- New `reorderMovementProvider = FutureProvider.autoDispose.family<ReorderMovement, int>`
  keyed by `windowDays`. Owns the existing fetch verbatim: window start =
  `DateTime(now.y, now.m, now.d) − (windowDays − 1)`, `getSalesByDateRange(..., status:
  completed, limit: reorderSalesCap)`. Returns
  `typedef ReorderMovement = ({Map<String, int> unitsSold, bool capped})` —
  `unitsSoldByProduct(sales)` and `sales.length >= reorderSalesCap`.
- `reorderSuggestionsProvider` keeps its name, family key (`ReorderParams`), and result type
  but becomes a **sync** `Provider.autoDispose.family<AsyncValue<ReorderResult>, ReorderParams>`:
  combine `ref.watch(productsProvider)` and `ref.watch(reorderMovementProvider(windowDays))`
  (loading/error of either wins, products first), then `whenData`-style compute of
  `computeReorderSuggestions` + the low/out bucketing + name sorts — logic moved, not changed.
- Screen (`new_purchase_order_screen.dart`): `ref.watch(reorderSuggestionsProvider(params))`
  already receives an `AsyncValue` — `.when` call site unchanged. Delete `_appliedCover`,
  `_coverDebounce`, and the Timer in `_setCover`; `params` uses `_cover` directly. Cover taps
  now recompute synchronously (no spinner, no refetch); the caption "applies as you change it"
  is literally true. Window changes still fetch and show the loading view as today.
- Not in scope (noted, deliberate): keepAlive on the movement provider (window revisits
  refetch, as today); any change to `reorderSalesCap` or the fetch itself.

**Tests:** existing screen-test overrides become
`reorderSuggestionsProvider.overrideWith((ref, params) => AsyncValue.data(...))`. The
debounce test is replaced by: override `reorderMovementProvider` recording fetch keys →
cover taps update the displayed qty immediately and never add a fetch; window tap adds one.
Provider-level test with fake repos: two cover values, one sales fetch.

## (b) One shared AddProductsSheet (PO + Job Orders)

**Problem:** `_AddProductsSheet` (PO) is a near-verbatim copy of `_AddPartsSheet` (JO) —
height clamp, grab handle, title row, `ProductSearchField` wiring, barcode handler. Fixes in
one drift past the other (the clamp crash guard already had to be applied twice).

**Design:** new `lib/presentation/mobile/widgets/pos/add_products_sheet.dart`:

```dart
enum AddProductsSheetDismiss { closeIcon, doneButton }

class AddProductsSheet extends ConsumerStatefulWidget {
  final String title;
  final void Function(ProductEntity) onProduct;
  final AddProductsSheetDismiss dismiss;   // JO: closeIcon · PO: doneButton
  final bool showSessionCount;             // 'N added this session' (PO)
  final bool showPrice;                    // JO true · PO false
  final bool allowOutOfStock;              // JO false · PO true
  final bool dedupe;                       // PO: Added chips + skip repeats
  final Set<String> initiallyAdded;        // seed for dedupe
  final bool clearQueryOnPick;             // JO: clear + refocus after a pick
  final String hintText;                   // default 'Search name, SKU, or scan barcode'
}
```

Owns once: the floored height clamp (`math.max(0, …)`), grab handle, title row (session
count right, or X close per `dismiss`), `ProductSearchField(inlineResults, showPrice,
allowOutOfStock, addedIds: dedupe ? added : const {})`, the barcode handler ("Product not
found" warning; with `dedupe`, "Already added: name" instead of a silent no-op), pinned
right-aligned Done when `dismiss == doneButton`. Sheet stays open across picks in both modes.

Call sites: `_AddPartsSheet` and `_AddProductsSheet` are deleted;
`draft_edit_screen._onAddParts` passes (title 'Add parts', closeIcon, clearQueryOnPick,
defaults otherwise) and `new_purchase_order_screen._showAddProductSheet` passes (title
'Add products', doneButton, showSessionCount, dedupe + initiallyAdded, showPrice false,
allowOutOfStock true). Behavior of both screens preserved exactly.

**Tests:** existing JO add-parts tests + PO sheet tests are the regression net; plus a new
`add_products_sheet_test.dart` covering the dedupe/Added-chip path and both dismiss styles.

## (c) Segmented control — move + tokenize (PO only)

**Problem:** `_SegmentedCells` is a generic ~100-line widget private to
`new_purchase_order_screen.dart`, with its selected wash as inline literals — the repo's 4th
divergent copy of the primary-wash value.

**Design:** move it verbatim to `po_widgets.dart` as public `PoSegmentedCells<T>` (same
constructor, same `Key('$keyPrefix-$name')` scheme so screen tests don't change), and add
`AppColors.segmentedSelectedWash(bool dark)` = `0x1FE8B84C` dark / `0x1A283E46` light,
consumed by the widget. **Deliberately untouched:** `SegmentedPillFilter`, the reports
screens' `SegmentedButton` overrides and their differing wash literals — reconciling them
would visibly change shipped screens for no functional gain. Revisit only when a new
consumer needs the bordered-cells style.

**Tests:** a `PoSegmentedCells` render/selection test in `po_widgets_test.dart`; the New-PO
screen tests keep passing unchanged (same keys).

## Sequencing & verification

One branch, tasks in order **(c) → (b) → (a)** (pure move first, riskiest last), each with
targeted `flutter test` + `flutter analyze`; full suite at the end. Success = all ~1090+
tests green, no visual change anywhere except cover stepping losing its spinner.
