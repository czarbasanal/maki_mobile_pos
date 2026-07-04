# Expenses Polish — Skeletons, Clickable History, Receipt Image

**Date:** 2026-07-04
**Backlog:** #12 (skeleton loading), #14 (history rows clickable), #15 (optional receipt image)
**Approved:** user approved design + the three scope answers (form + tap-to-zoom viewer;
camera + gallery picker; non-admin taps do nothing).

## 1. #12 — Skeletons on all expense loading states

The expense lists (`expenses_screen.dart`, `expense_history_screen.dart`) already use
`ListSkeleton`. Replace the three remaining spinner/placeholder states:

| Where | Today | Becomes |
|---|---|---|
| `expense_form_screen.dart` edit-mode initial load (`_isLoading`) | `Center(CircularProgressIndicator())` | `FormSkeleton` — new reusable widget in `app_skeleton.dart`: N field-shaped `SkeletonBox`es (height ~56, field radius) stacked with 16px gaps + a button-shaped box at the bottom, inside the same 16px page padding |
| `_TotalCard` (expenses dashboard) loading | value `'…'` | `SummaryCard` gains an optional `loading: bool` (default false); when true it renders a `SkeletonBox` (~48×16) in place of the value text. `_TotalCard` passes `loading: totalAsync.isLoading` |
| Category dropdowns: `_CategoryFilterDropdown` (dashboard), `_HistoryCategoryFilter` (history), `_ExpenseCategoryDropdown` (form) | `LinearProgressIndicator` | `FieldSkeleton` — new one-liner in `app_skeleton.dart`: a single field-shaped `SkeletonBox` (height 56, field radius) |

No other screens change (avoid scope creep; other dropdown loaders around the app can
adopt `FieldSkeleton` later).

## 2. #14 — Expense history rows clickable

`expense_history_screen.dart`: watch `currentUserProvider` role; when the user has
`Permission.editExpense` (admin), pass
`onTap: () => context.push('${RoutePaths.expenses}/edit/${e.id}')` to `ExpenseRow` —
identical gate + route to the dashboard's recent list. No tap for staff/cashier. No
delete/dismiss added to history (out of scope).

**Receipt indicator:** `ExpenseRow` gains an optional `hasReceipt: bool` (default false);
when true, a small muted `LucideIcons.paperclip` (size ~14) renders between the subtitle
column and the amount. Both list call sites pass `expense.receiptImageUrl != null`.

## 3. #15 — Optional receipt image on expenses

### Data

- `ExpenseEntity`: new `final String? receiptImageUrl` + constructor param + `copyWith`
  (with `clearReceiptImageUrl` flag, mirroring `clearNotes`) + `props`.
- `ExpenseModel`: field + `fromFirestore` / `toCreateMap` / `toUpdateMap` / `fromEntity` /
  `toEntity` threading, all nullable.

### Storage

- New `lib/services/expense_receipt_storage_service.dart` — mirrors
  `ProductImageStorageService`: path `expenses/{expenseId}/receipt.jpg`, `upload()` returns
  download URL, `delete()` no-ops on `object-not-found`, Riverpod provider.
- `storage.rules`: add a match block for `expenses/{expenseId}/{file=**}` identical in
  shape to the products block (auth'd read; write = auth + (<2MB + `image/*` on upload)).
  **Deploy is production-affecting — build everything first, then ask the user before
  `firebase deploy --only storage`.** Until deployed, uploads fail under default-deny and
  the best-effort path (below) degrades cleanly.

### Upload flow — constrained by Firestore rules

Firestore `expenses` rules: all active users **create**; only admin **update**. The
product pattern (create → upload → update URL back) would fail for cashier/staff. So:

- `ExpenseRepository` gains `String newExpenseId()` (returns `_expensesRef.doc().id`), and
  `createExpense` **honors a non-empty `expense.id`** (`doc(id).set(...)` instead of
  `add(...)`; empty id keeps the `add()` path).
- **Create with receipt:** form pre-allocates the id, uploads bytes to
  `expenses/{id}/receipt.jpg`, then creates the doc with `receiptImageUrl` set — all inside
  the existing `runWithWaiting` "Saving…" closure. Upload failure → best-effort: create
  without the image, then `showWarningSnackBar('Receipt upload failed — expense saved
  without receipt')` (products' convention).
- **Edit (admin-only by rules):** new/replaced image uploads to the same path
  (overwrite), then the doc updates with the new URL. Remove → update doc with
  `clearReceiptImageUrl`, then best-effort `delete()` the storage object. Same best-effort
  warning on upload failure.
- **Delete expense:** after a successful doc delete, best-effort `delete()` the storage
  object (admin-only path). Applies to the form's delete and both list deletes — factor
  the cleanup into the operations notifier if cleaner.

### Form UI

New `ReceiptImageField` in `lib/presentation/mobile/widgets/expenses/`:

- Empty state: dashed/outlined "Add receipt photo" tile (camera icon + label), full-width,
  ~96px tall. Optional field — sits between Notes and the submit button, labeled
  "Receipt (optional)".
- Tap → bottom sheet: **Take photo** (`ImagePicker.pickImage(source: camera)`) /
  **Choose from gallery**. No crop step — receipts are documents; keep original aspect.
- Compress via `flutter_image_compress` to max edge **1600px**, JPEG quality ~80 (receipt
  text must stay legible; product's 1024 is too small) — stays well under the 2MB rule.
- Filled state: preview thumbnail (maxHeight ~160, rounded, `BoxFit.cover` off —
  `contain`), tap → full-screen viewer (`InteractiveViewer` in a dialog/route over a dark
  scrim, pinch-zoom), plus **Replace** and **Remove** actions.
- Displays either pending local bytes (fresh pick) or `receiptImageUrl` (network) —
  mirroring `ProductImageUploader`'s dual-source preview.
- Form state: `_pendingReceiptBytes`, `_receiptMarkedForRemoval`; both join `_sig()` so
  dirty-checking gates the Update button, exactly like the product form.

### Who sees what

Anyone who can add an expense can attach a receipt on create. Editing/removing a receipt
rides the existing edit gate (admin). Viewer is available wherever the form is readable.

## Error handling

- Upload failures never block the expense write (best-effort + warning snackbar).
- Storage delete failures are swallowed (orphan objects are harmless; path is
  deterministic so a later re-upload overwrites).
- All writes stay inside the existing `runWithWaiting` dialogs; rethrow semantics
  unchanged.

## Testing

- Entity/model: `receiptImageUrl` round-trip (fromFirestore/toCreateMap/toUpdateMap,
  copyWith + clear flag, props).
- Repo: `createExpense` uses `set` with preset id / `add` without (fake_cloud_firestore,
  matching existing repo tests).
- History screen: admin rows tap through to edit route; cashier rows have no onTap;
  paperclip renders only when `receiptImageUrl != null`.
- Skeletons: `FormSkeleton`/`FieldSkeleton` render; form shows `FormSkeleton` while
  loading; `SummaryCard(loading: true)` shows a `SkeletonBox`, not the value.
- `ReceiptImageField`: empty vs preview vs marked-for-removal states from injected
  bytes/url (picker plugin itself not exercised).
- Full `flutter test` + `flutter analyze` green before done.

## Delivery

One branch (`feat/expenses-polish`), commits per item (#12, #14, #15). `storage.rules`
edited in-repo with the #15 commit but **deployed only after user confirmation**. Device
smoke (camera path) is the user's gate — camera can't be exercised in tests.
