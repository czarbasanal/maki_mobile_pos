# Staff product creation + cashier add-product gating

Date: 2026-05-28
Status: Approved (design)

## Problem

On the inventory screen the "Add Product" button is shown to every role, but
product creation is locked to **admin** at five layers (permission set,
`CreateProductUseCase` assert, Firestore rules, the form's admin-only create
branch, and the form's price/cost field gating). So cashiers and staff see a
button that cannot succeed.

Two desired outcomes:

1. **Cashier** must not see the Add Product button at all.
2. **Staff** should be able to create products — including setting a price —
   but must never see or type a numeric cost. Staff instead enter the product's
   **cost code** (the existing letter cipher, e.g. `NBF`), which the system
   decodes to the real cost behind the scenes.

## Background: cost codes

`CostCodeEntity` (`lib/domain/entities/cost_code_entity.dart`) encodes a number
to letters and back:

- `encode(125.0)` → `"NBF"`
- `decode("NBF")` → `125.0`, `decode(<invalid>)` → `null`

The mapping is stored in Firestore settings and is readable by every valid user
(`settings` read allows `isValidUser()`), so the client can translate codes.
Providers already exist: `costCodeMappingProvider`, `encodeCostProvider`,
`decodeCostProvider`, `isValidCostCodeProvider`
(`lib/presentation/providers/cost_code_provider.dart`).

Cost confidentiality in this app is **UI-level only** — the mapping has always
been readable. This design does not change that posture.

## Approach

Reuse the existing permission model rather than hardcoding role checks or adding
a new permission. Grant staff the existing `Permission.addProduct`, gate the UI
on that permission, and handle the "no numeric cost for staff" rule via the
cost-code field (UI) plus an authoritative decode in the use case (logic).
Considered and rejected: hardcoded role checks (drifts from the app's
single-source-of-truth permission system) and a separate `addProductLimited`
permission (YAGNI — only two roles need the distinction).

## Changes by layer

### A. Inventory screen — `lib/presentation/mobile/screens/inventory/inventory_screen.dart`

Compute `canAddProduct = currentUser?.hasPermission(Permission.addProduct) ?? false`.
Gate both Add Product entry points on it:

- the bottom `FilledButton.icon` (lines ~138-142), and
- the "Add Product" item in the overflow `PopupMenuButton` (lines ~88-95).

Import/Export menu items are unchanged. Result: cashier sees neither entry
point; staff and admin see both.

### B. Permission model — `lib/core/constants/role_permissions.dart`

Add `Permission.addProduct` to `_staffPermissions`. Update the now-incorrect
comment at line 121 (`addProduct is NOT included`).

### C. Product form — `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

Scope: **create path only**. Staff editing of existing products is unchanged
(still cannot alter price/cost/costCode).

Field gating, when `!isEditing` (creating):

- Staff may edit **price** and **SKU** (today `canEditPrice` and the SKU field
  are admin-only).
- Staff see a **Cost Code** text field instead of the numeric cost field. The
  numeric cost is never rendered for staff.
- Cost-code input is validated live with `isValidCostCodeProvider`; an invalid
  code blocks save with an inline error.
- Supplier selection stays admin-only; staff-created products have no supplier
  (admin can set it later).

Create branch (currently the "ADMIN ONLY" `else` at line ~901): split by role.

- Admin: unchanged — enters numeric cost; `costCode = encode(cost)`.
- Staff: build the `ProductEntity` with the entered `costCode`, `price`,
  `sku`, `quantity`, `unit`, `category`, `barcodes`, `reorderLevel`, image;
  leave `cost` unset/0 and `supplierId` null. The authoritative cost is derived
  in the use case (below).

### D. Create use case — `lib/domain/usecases/product/create_product_usecase.dart`

Inject the cost-code mapping (via `CostCodeRepository` / the mapping entity).
Keep the existing `assertPermission(actor, Permission.addProduct)` (now passes
for staff). Then, for a **non-admin** actor:

- `final cost = mapping.decode(product.costCode);`
- if `cost == null` → return failure `"Invalid cost code"`.
- otherwise create with `cost` set from the decode and `costCode` normalized to
  `encode(cost)`; ignore any client-submitted numeric cost.

Admin actors keep current behavior. This makes the decode the single
authoritative translation and keeps the numeric cost out of the UI layer
entirely, mirroring how `UpdateProductUseCase` enforces field rules in logic.

### E. Firestore rules — `firestore.rules`

Split the products `allow create, delete: if isAdmin()` rule:

```
allow delete: if isAdmin() && isActiveUser();
allow create: if (isAdmin() || hasRole('staff')) && isActiveUser();
```

Cashier still cannot create (not matched). No `cost == 0` constraint: staff
legitimately set a real cost via the code, and rules cannot feasibly re-run the
decode (multi-char zero codes) to verify it. Delete remains admin-only.

## Testing

Firestore rules suite (`tools/firestore-rules-test/test/rules.test.js`):

- staff (active) can create a product; cashier cannot; admin can.
- inactive staff cannot create.
- delete remains admin-only for staff and cashier.

Use-case unit test for `CreateProductUseCase`:

- staff actor + valid cost code → product persisted with the decoded cost.
- staff actor + invalid cost code → failure, nothing written.
- admin actor path unchanged (numeric cost in, `encode` out).

Manual verification (no Flutter widget-test harness in this repo):

- cashier: no Add Product button or menu item on inventory.
- staff: Add Product visible; create form shows Cost Code field (no numeric
  cost), price + SKU editable; saving a valid code creates a sellable product;
  invalid code is rejected.
- admin: unchanged.

## Out of scope

- Staff editing cost/price on existing products.
- Staff supplier selection and SKU auto-generation.
- Strengthening cost confidentiality (mapping readability is pre-existing).
- CSV import (still admin-only / stubbed).
