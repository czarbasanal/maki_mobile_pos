# Deploy Fixes Design
**Date:** 2026-05-23
**Scope:** Three post-deploy issues: photo upload crash, supplier field visibility, cashier product name-only editing.

---

## 1. Photo Upload — Silent App Exit Fix

### Root Cause
`image_cropper` launches a native Activity (UCropActivity on Android). The OS deprioritizes the Flutter process while the native UI is active and kills it under memory pressure when the source image is large. The same memory pressure causes Firebase upload to OOM when bytes are uncompressed.

### Fix: Compress Before Crop

**Current pipeline in `ProductImageUploader._pickAndProcess()`:**
```
ImagePicker → ImageCropper (native, full-res file) → FlutterImageCompress → bytes → parent
```

**New pipeline:**
```
ImagePicker → FlutterImageCompress (temp file, max edge 400px, quality 80) → ImageCropper (native, small file) → read bytes → parent
```

The cropper receives a compressed temp file (~400px max edge, quality 80) instead of the original full-resolution file. After cropping, the resulting file bytes are read and passed to the parent — no second compression needed.

### Error Handling

**In `ProductImageUploader._pickAndProcess()`:**
- Wrap the crop call in try/catch
- On exception or null return (user cancels or native crash): show SnackBar *"Could not process image. Please try again."* and return without changing state

**In `ProductFormScreen._handleSubmit()`:**
- Wrap `storage.upload(productId, bytes)` in try/catch
- On failure: show SnackBar *"Image upload failed — product saved without image."*
- The product entity still saves successfully; only the image is skipped

### Files Changed
- `lib/presentation/mobile/widgets/inventory/product_image_uploader.dart`
- `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

---

## 2. Supplier Field Visibility — Cashier and Staff

### Rule
Supplier is **admin-only** — hidden for cashier and staff on both the product detail screen and the product form screen.

### Product Detail Screen
**File:** `lib/presentation/mobile/screens/inventory/product_detail_screen.dart`

Supplier Card currently renders when `product.supplierName != null`. Add role check:

```dart
if (product.supplierName != null && userRole == UserRole.admin)
  _SupplierCard(...)
```

### Product Form Screen
**File:** `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

Currently staff sees a read-only supplier field. New rule: hide the supplier field entirely for any role that is not admin. The `canSelectSupplier` boolean already exists — extend it to gate visibility, not just editability:

```dart
final bool showSupplier = userRole == UserRole.admin;
// Render supplier field only if showSupplier == true
```

---

## 3. Cashier — Product Name-Only Editing

### Permission Layer
**File:** `lib/core/constants/role_permissions.dart`

- Add `editProductNameOnly` to the `Permission` enum
- Assign it to the **cashier** role's permission set
- Add helper method:

```dart
static bool canEditProductNameOnly(UserRole role) => role == UserRole.cashier;
```

**Role edit capability summary:**

| Role | Permission | Capability |
|------|-----------|------------|
| Admin | `editProduct` | Full edit |
| Staff | `editProductLimited` | All fields except price/cost |
| Cashier | `editProductNameOnly` | Name only; supplier hidden |

### Product Detail Screen
**File:** `lib/presentation/mobile/screens/inventory/product_detail_screen.dart`

Edit button is currently gated on `Permission.editProduct`. Expand to include all three edit permissions:

```dart
PermissionGate.any(
  permissions: [
    Permission.editProduct,
    Permission.editProductLimited,
    Permission.editProductNameOnly,
  ],
  child: EditButton(),
)
```

### Product Form Screen
**File:** `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

Derive a `isNameOnly` boolean alongside existing role booleans:

```dart
final bool isNameOnly = userRole == UserRole.cashier;
```

**Info banner** (matches existing staff banner pattern):
> *"You can only edit the product name."*

**Field behavior when `isNameOnly == true`:**

| Field | Behavior |
|-------|----------|
| Product image | Disabled (`enabled: false` on uploader) |
| SKU | Disabled |
| Product name | **Enabled** — only editable field |
| Selling price | Disabled |
| Cost | Disabled |
| Initial quantity | Disabled |
| Reorder level | Disabled |
| Unit | Disabled |
| Barcodes | Disabled (no add/remove) |
| Category | Disabled |
| Supplier | **Hidden** (consistent with §2) |
| Notes | Disabled |
| Audit info card | Visible, unchanged |

**On submit:** Only the `name` field value is applied. All other fields pass through their original values unchanged, following the same pattern as staff's price/cost preservation.

---

## Out of Scope (Deferred)
- In-app barcode scanning with specified viewfinder area — deferred to a future session
