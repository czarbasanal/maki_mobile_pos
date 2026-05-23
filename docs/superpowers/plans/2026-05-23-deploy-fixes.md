# Deploy Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix a silent app-exit during photo upload, hide supplier from cashier/staff everywhere, and allow cashier to edit only the product name.

**Architecture:** Three independent changes across four files. No new dependencies. The permission layer change is additive (new enum value + helper). UI changes follow the existing role-boolean pattern already established for staff.

**Tech Stack:** Flutter, Dart, Riverpod, image_picker, image_cropper, flutter_image_compress, Firebase Storage

---

## File Map

| File | Change |
|------|--------|
| `lib/core/constants/role_permissions.dart` | Add `editProductNameOnly` permission + cashier set + helper method |
| `lib/presentation/mobile/widgets/inventory/product_image_uploader.dart` | Compress before crop; wrap crop in try/catch |
| `lib/presentation/mobile/screens/inventory/product_form_screen.dart` | Isolate upload errors; remove staff read-only supplier field; add `isNameOnly` cashier mode + submit branch |
| `lib/presentation/mobile/screens/inventory/product_detail_screen.dart` | Hide supplier card for non-admin |

---

### Task 1: Add `editProductNameOnly` permission for cashier

**Files:**
- Modify: `lib/core/constants/role_permissions.dart`
- Create: `test/core/constants/role_permissions_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/core/constants/role_permissions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';

void main() {
  group('RolePermissions — editProductNameOnly', () {
    test('cashier has editProductNameOnly', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.cashier, Permission.editProductNameOnly),
        isTrue,
      );
    });

    test('staff does not have editProductNameOnly', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.staff, Permission.editProductNameOnly),
        isFalse,
      );
    });

    test('admin does not have editProductNameOnly', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.admin, Permission.editProductNameOnly),
        isFalse,
      );
    });

    test('canEditProductNameOnly is true only for cashier', () {
      expect(RolePermissions.canEditProductNameOnly(UserRole.cashier), isTrue);
      expect(RolePermissions.canEditProductNameOnly(UserRole.staff), isFalse);
      expect(RolePermissions.canEditProductNameOnly(UserRole.admin), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test — confirm compilation failure**

```bash
flutter test test/core/constants/role_permissions_test.dart
```

Expected: compilation error — `Permission.editProductNameOnly` does not exist yet.

- [ ] **Step 3: Add `editProductNameOnly` to the Permission enum**

In `lib/core/constants/role_permissions.dart`, after line 22 (`editProductLimited`):

```dart
  editProduct, // Full edit including price (admin only)
  editProductLimited, // Edit without price field (staff only)
  editProductNameOnly, // Edit product name only (cashier)
  deleteProduct,
```

- [ ] **Step 4: Add to `_cashierPermissions` set**

After `Permission.viewInventory` in `_cashierPermissions` (around line 89):

```dart
    // Inventory (view only, no cost, name edit only)
    Permission.viewInventory,
    Permission.editProductNameOnly,
```

- [ ] **Step 5: Add `canEditProductNameOnly` helper method**

After the `canEditProductFull` method (after line 263):

```dart
  /// Checks if a role can edit only the product name (cashier).
  static bool canEditProductNameOnly(UserRole role) {
    return hasPermission(role, Permission.editProductNameOnly) &&
        !hasPermission(role, Permission.editProductLimited) &&
        !hasPermission(role, Permission.editProduct);
  }
```

- [ ] **Step 6: Run tests — confirm they pass**

```bash
flutter test test/core/constants/role_permissions_test.dart
```

Expected: 4 tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/role_permissions.dart test/core/constants/role_permissions_test.dart
git commit -m "feat: add editProductNameOnly permission for cashier role"
```

---

### Task 2: Fix photo upload — compress before crop

**Files:**
- Modify: `lib/presentation/mobile/widgets/inventory/product_image_uploader.dart`

- [ ] **Step 1: Add `dart:io` import**

At the top of the file, after `import 'dart:typed_data';`:

```dart
import 'dart:io';
import 'dart:typed_data';
```

- [ ] **Step 2: Change default `cropMaxEdge` to 400**

In the constructor default values:

```dart
  this.cropMaxEdge = 400,
  this.jpegQuality = 80,
```

(Was 480. 400px is the agreed preview size that stays small enough to avoid OOM in the native crop Activity.)

- [ ] **Step 3: Replace `_pick` body from the ImagePicker call onward**

Replace everything from `final picker = ImagePicker();` through `onChanged(Uint8List.fromList(compressed), removed: false);` (lines 84–116) with:

```dart
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null || !context.mounted) return;

    // Compress to a temp file before cropping so the native crop Activity
    // loads a small file — prevents the silent OS kill caused by memory
    // pressure when the original full-resolution image is large.
    final tempPath =
        '${Directory.systemTemp.path}/maki_pre_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    XFile? smallFile;
    try {
      smallFile = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        tempPath,
        minWidth: cropMaxEdge,
        minHeight: cropMaxEdge,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Non-fatal: fall back to the original file if pre-compression fails.
    }

    final sourcePath = smallFile?.path ?? picked.path;

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop image',
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop image',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not process image. Please try again.'),
          ),
        );
      }
    } finally {
      // Clean up temp file regardless of crop outcome.
      if (smallFile != null) {
        try {
          File(tempPath).deleteSync();
        } catch (_) {}
      }
    }

    if (cropped == null) return;

    // The cropped file is already small (source was pre-compressed to
    // cropMaxEdge). Read bytes directly — no second compression needed.
    final bytes = await File(cropped.path).readAsBytes();
    onChanged(Uint8List.fromList(bytes), removed: false);
```

- [ ] **Step 4: Run the app and test manually**

On Android or iOS: navigate to any product → tap the image thumbnail → pick from gallery → crop → confirm the image appears without the app exiting.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/inventory/product_image_uploader.dart
git commit -m "fix: compress image before crop to prevent silent OS kill under memory pressure"
```

---

### Task 3: Isolate image upload errors in product form

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

- [ ] **Step 1: Wrap the admin-edit image upload in its own try/catch**

In `_handleSubmit`, find the admin edit upload block (around line 724). Replace:

```dart
          String? newImageUrl;
          var clearImage = false;
          if (_pendingImageBytes != null) {
            final storage =
                ref.read(productImageStorageServiceProvider);
            newImageUrl = await storage.upload(
              productId: _existingProduct!.id,
              bytes: _pendingImageBytes!,
            );
          } else if (_imageMarkedForRemoval) {
```

With:

```dart
          String? newImageUrl;
          var clearImage = false;
          if (_pendingImageBytes != null) {
            try {
              final storage = ref.read(productImageStorageServiceProvider);
              newImageUrl = await storage.upload(
                productId: _existingProduct!.id,
                bytes: _pendingImageBytes!,
              );
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Image upload failed — product saved without image.',
                    ),
                  ),
                );
              }
            }
          } else if (_imageMarkedForRemoval) {
```

- [ ] **Step 2: Wrap the create-flow image upload in its own try/catch**

In `_handleSubmit`, find the create-flow image upload (around line 848). Replace:

```dart
        if (_pendingImageBytes != null) {
          final storage = ref.read(productImageStorageServiceProvider);
          final url = await storage.upload(
            productId: created.id,
            bytes: _pendingImageBytes!,
          );
          await productOps.updateProduct(
            actor: currentUser,
            product: created.copyWith(imageUrl: url),
          );
        }
```

With:

```dart
        if (_pendingImageBytes != null) {
          try {
            final storage = ref.read(productImageStorageServiceProvider);
            final url = await storage.upload(
              productId: created.id,
              bytes: _pendingImageBytes!,
            );
            await productOps.updateProduct(
              actor: currentUser,
              product: created.copyWith(imageUrl: url),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Image upload failed — product saved without image.',
                  ),
                ),
              );
            }
          }
        }
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "fix: isolate image upload errors so product save succeeds even when upload fails"
```

---

### Task 4: Hide supplier card from non-admin in product detail screen

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_detail_screen.dart`

- [ ] **Step 1: Pass `isAdmin` into `_buildProductDetails`**

The `isAdmin` variable is declared in `build()` but `_buildProductDetails` is a separate method that currently does not receive it. Update the method signature:

```dart
  Widget _buildProductDetails(
    BuildContext context,
    WidgetRef ref,
    ProductEntity product,
    InventoryState inventoryState,
    bool isAdmin,
  ) {
```

Update the call site in `build()` (around line 72):

```dart
          return _buildProductDetails(
              context, ref, product, inventoryState, isAdmin);
```

- [ ] **Step 2: Add the `isAdmin` role check to the supplier card**

In `_buildProductDetails`, find (around line 122):

```dart
          if (product.supplierName != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildSupplierCard(context, product),
          ],
```

Replace with:

```dart
          if (product.supplierName != null && isAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            _buildSupplierCard(context, product),
          ],
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_detail_screen.dart
git commit -m "feat: hide supplier card from staff and cashier in product detail screen"
```

---

### Task 5: Hide supplier field from non-admin in product form screen

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

- [ ] **Step 1: Remove the staff read-only supplier field**

Find and delete this entire block (around line 503):

```dart
                    // Show supplier as read-only for staff
                    if (!canSelectSupplier &&
                        _existingProduct?.supplierName != null)
                      TextFormField(
                        initialValue: _existingProduct?.supplierName ?? 'None',
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          prefixIcon: Icon(CupertinoIcons.briefcase),
                          ),
                        enabled: false,
                      ),
```

After deletion, the `if (canSelectSupplier)` dropdown above it remains — supplier is now admin-only on this screen.

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "feat: hide supplier field from staff and cashier in product form"
```

---

### Task 6: Add cashier name-only mode to product form

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

- [ ] **Step 1: Add `isNameOnly` to the role-capability block in `build()`**

Find (around line 163):

```dart
    final bool canSelectSupplier = userRole == UserRole.admin;
```

Add immediately after:

```dart
    final bool canSelectSupplier = userRole == UserRole.admin;
    // Cashier can reach the edit form but may only change the product name.
    final bool isNameOnly = userRole == UserRole.cashier;
```

- [ ] **Step 2: Add cashier info banner**

Find the staff info banner block (around line 215):

```dart
                    // Role info banner for staff — outlined info pill
                    if (userRole == UserRole.staff && widget.isEditing)
                      Container(
                        ...
                      ),
```

Add the cashier banner immediately after it (after the closing `,`):

```dart
                    // Role info banner for cashier
                    if (isNameOnly && widget.isEditing)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.sm + 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.info),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.info_circle,
                              color: AppColors.infoDark,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'You can only edit the product name.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.infoDark),
                              ),
                            ),
                          ],
                        ),
                      ),
```

- [ ] **Step 3: Disable quantity, reorder level, and notes fields for cashier**

Add `enabled: !isNameOnly,` to the Quantity field (around line 391):

```dart
                    TextFormField(
                      controller: _quantityController,
                      enabled: !isNameOnly,
                      decoration: const InputDecoration(
                        labelText: 'Initial Quantity *',
                        prefixIcon: Icon(CupertinoIcons.number),
                      ),
```

Add `enabled: !isNameOnly,` to the Reorder Level field (around line 411):

```dart
                    TextFormField(
                      controller: _reorderLevelController,
                      enabled: !isNameOnly,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
```

Add `enabled: !isNameOnly,` to the Notes field (around line 518):

```dart
                    TextFormField(
                      controller: _notesController,
                      enabled: !isNameOnly,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
```

- [ ] **Step 4: Disable unit and category dropdowns for cashier via AbsorbPointer**

`_AdminListDropdownField` has no `enabled` parameter. Wrap both usages in `AbsorbPointer` + `Opacity` — Flutter's standard pattern for disabling interactive widgets that don't expose an `enabled` flag.

Unit dropdown (around line 425):

```dart
                    AbsorbPointer(
                      absorbing: isNameOnly,
                      child: Opacity(
                        opacity: isNameOnly ? 0.38 : 1.0,
                        child: _AdminListDropdownField(
                          kind: CategoryKind.unit,
                          controller: _unitController,
                          label: 'Unit',
                          icon: Icons.straighten,
                          onChanged: (value) {
                            setState(() {
                              _unitController.text = value ?? '';
                            });
                          },
                        ),
                      ),
                    ),
```

Category dropdown (around line 449):

```dart
                    AbsorbPointer(
                      absorbing: isNameOnly,
                      child: Opacity(
                        opacity: isNameOnly ? 0.38 : 1.0,
                        child: _AdminListDropdownField(
                          kind: CategoryKind.product,
                          controller: _categoryController,
                          label: 'Category',
                          icon: CupertinoIcons.square_grid_2x2,
                          includeNoneOption: true,
                          onChanged: (value) {
                            setState(() {
                              _categoryController.text = value ?? '';
                            });
                          },
                        ),
                      ),
                    ),
```

- [ ] **Step 5: Add `enabled` parameter to `_buildBarcodesField` and disable for cashier**

Change the method signature from:

```dart
  Widget _buildBarcodesField() {
```

To:

```dart
  Widget _buildBarcodesField({bool enabled = true}) {
```

Inside the method, gate the delete action on chips and hide the add input when disabled:

Change each `InputChip` from:

```dart
              InputChip(
                label: Text(code),
                onDeleted: () {
                  setState(() {
                    _barcodes.remove(code);
                    _barcodeError = null;
                  });
                },
              ),
```

To:

```dart
              InputChip(
                label: Text(code),
                onDeleted: enabled
                    ? () {
                        setState(() {
                          _barcodes.remove(code);
                          _barcodeError = null;
                        });
                      }
                    : null,
              ),
```

Wrap the add-barcode `TextField` block in `if (enabled)`:

```dart
        if (enabled) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _barcodeInputController,
            decoration: InputDecoration(
              labelText: 'Add barcode',
              hintText: 'e.g. 4806504801108',
              prefixIcon: const Icon(CupertinoIcons.barcode_viewfinder),
              errorText: _barcodeError,
              suffixIcon: IconButton(
                tooltip: 'Add',
                icon: const Icon(CupertinoIcons.add),
                onPressed: _addBarcodeFromInput,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addBarcodeFromInput(),
          ),
        ],
```

Update the call site in `build()` to pass the flag:

```dart
                    _buildBarcodesField(enabled: !isNameOnly),
```

- [ ] **Step 6: Add cashier branch to `_handleSubmit`**

In `_handleSubmit`, find the end of the staff branch (around line 798):

```dart
          if (result == null) throw Exception('Failed to update product');
        }
      } else {
        // ==================== CREATE LOGIC (ADMIN ONLY) ====================
```

Insert the cashier branch between the staff branch and the else (create logic):

```dart
          if (result == null) throw Exception('Failed to update product');
        } else if (userRole == UserRole.cashier) {
          // Cashier: update name only. All other fields preserved from original.
          final product = _existingProduct!.copyWith(
            name: _nameController.text.trim(),
            price: _existingProduct!.price,
            cost: _existingProduct!.cost,
            costCode: _existingProduct!.costCode,
            quantity: _existingProduct!.quantity,
            reorderLevel: _existingProduct!.reorderLevel,
            unit: _existingProduct!.unit,
            supplierId: _existingProduct!.supplierId,
            supplierName: _existingProduct!.supplierName,
            barcodes: List<String>.from(_existingProduct!.barcodes),
            category: _existingProduct!.category,
            notes: _existingProduct!.notes,
          );
          final productOps = ref.read(productOperationsProvider.notifier);
          final result = await productOps.updateProduct(
            actor: currentUser,
            product: product,
          );
          if (result == null) throw Exception('Failed to update product');
        }
      } else {
        // ==================== CREATE LOGIC (ADMIN ONLY) ====================
```

- [ ] **Step 7: Manually test the cashier edit flow**

Log in as a cashier → open any product detail → tap the pencil icon → confirm:
1. Banner reads *"You can only edit the product name."*
2. Only the product name field accepts input; all other text fields are greyed out
3. Unit and category dropdowns are greyed and non-interactive
4. Barcode chips have no delete button; add-barcode input is hidden
5. Supplier field is absent
6. Tapping "Update Product" saves only the name change; all other values remain the same

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "feat: restrict cashier product editing to name-only with informational banner"
```
