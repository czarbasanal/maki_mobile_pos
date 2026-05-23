# Multi-Branch Architecture Design

**Date:** 2026-05-11
**Status:** Draft — awaiting user review
**Scope:** Convert MAKI Mobile POS (Flutter mobile + web admin, Firestore backend) from a single-tenant, single-location system into a multi-branch franchise/chain platform.

## 1. Goals & Scenario

Target: franchise/chain operator with 10+ branches, potentially different operators per location, hard isolation between branches at the data layer, head-office consolidation across all branches.

### In scope (v1)
- `branches` entity and per-branch operation across mobile and web
- Per-branch inventory (stock, cost, reorder level, price override)
- Global product catalog with per-branch pricing & cost overrides
- User-to-branch assignment with multi-branch support
- Active-branch state on each device, with picker for multi-branch users
- Firestore Rules enforcing branch isolation
- Per-branch settings (tax override, receipt header, cost code mapping)
- HQ admin "All branches" cross-branch reporting mode
- Branch management UI in both mobile and web admin
- New role: `manager` (per-branch admin permissions)
- Stock transfers **schema only** (no UI)

### Out of scope (explicitly deferred)
- Stock transfer UI (v2)
- Cross-tenant SaaS multi-tenancy (single company only)
- Per-branch product catalog activation/deactivation
- Per-branch tax engines beyond a single rate override
- Migration of live data — clean reset accepted (pilot/dev only today)
- Per-branch currency in the UI (currency stored on branch, but app uses single global formatter in v1)
- Offline conflict resolution beyond Firestore defaults
- Inventory ledger / append-only movement log
- Customer database (no customer entity exists yet)

## 2. Architecture Overview

Single Firebase project. Firestore Rules enforce branch isolation via a user-document lookup. Both apps (Flutter mobile/web target and React web admin) read an "active branch" state and pass `branchId` explicitly through every repository call that touches branched data. The product catalog remains global; everything transactional or stock-related is branched.

```
┌──────────────────────────┐    ┌──────────────────────────┐
│  Flutter app (mobile/web)│    │  React web admin         │
│  - activeBranchProvider  │    │  - useActiveBranch()     │
│  - branch picker         │    │  - branch selector       │
│  - AppBar branch chip    │    │  - branches mgmt UI      │
└────────────┬─────────────┘    └────────────┬─────────────┘
             │                               │
             └──────────┬────────────────────┘
                        │
                  ┌─────▼──────┐
                  │  Firestore │  (rules enforce hasBranch() on every doc)
                  └─────┬──────┘
                        │
   ┌────────────────────┼─────────────────────┐
   │                    │                     │
┌──▼────────┐  ┌────────▼──────────┐  ┌──────▼─────────────┐
│ Global    │  │ Per-branch        │  │ Branched           │
│ - products│  │ - branches/{id}   │  │ transactional      │
│ - users   │  │ - branch_inventory│  │ - sales            │
│ - settings│  │ - branches/{id}/  │  │ - drafts           │
│ (template)│  │   settings/*      │  │ - receivings       │
└───────────┘  └───────────────────┘  │ - expenses         │
                                      │ - petty_cash       │
                                      │ - user_logs        │
                                      │ - stock_transfers  │
                                      │   (v2 schema only) │
                                      └────────────────────┘
```

## 3. Schema

### 3.1 `branches/{branchId}` (new)

```
{
  id: string,
  name: string,
  code: string,            // e.g. "BR01", used as sale-number prefix; unique
  address: string,
  timezone: string,
  currency: string,        // stored, not enforced in v1 UI
  taxRateOverride: number | null,
  status: 'active' | 'inactive',
  createdAt: timestamp,
  createdBy: string        // userId
}
```

### 3.2 `products/{productId}` (changed — master catalog, HQ-owned)

**Removed fields:** `quantity`, `cost` (both move to `branch_inventory`).

**Retained:** `name`, `barcode(s)`, `category`, `unit`, `defaultPrice`, `reorderLevelDefault?`, `imageUrl`, `isActive`, timestamps.

No `branchId` on the product. The catalog is global.

### 3.3 `branch_inventory/{branchId}_{productId}` (new)

```
{
  branchId: string,
  productId: string,
  quantity: int,
  reorderLevel: int,
  cost: number,                  // per-branch (suppliers/freight differ)
  priceOverride: number | null,  // null → use product.defaultPrice
  lastReceivedAt: timestamp | null,
  lastSoldAt: timestamp | null,
  updatedAt: timestamp
}
```

The composite doc ID `{branchId}_{productId}` provides O(1) lookup and a natural unique constraint per pair. Sale transactions decrement this doc, not the product doc.

### 3.4 `users/{userId}` (changed)

**Added fields:**
- `assignedBranchIds: string[]` — branches this user can operate in
- `defaultBranchId?: string` — pre-selected at login if user has multiple

**Role enum (changed):** `admin | manager | staff | cashier`

- `admin` — global; all branches implicitly assigned (rule helper `isAdmin()` bypasses branch checks); manages HQ settings template, master product catalog, branch creation, and role assignment
- `manager` — **admin-equivalent power scoped to `assignedBranchIds`**. Can do anything admins can do *within* their branches, including: edit branch metadata, edit per-branch settings (cost codes, tax override, receipt config), edit `branch_inventory` (cost, price override, reorder level), delete transactional docs (sales, expenses, etc.), and create/edit `staff`/`cashier` users assigned to those branches. **Cannot** touch HQ-scoped things: master product catalog, global settings, the cost-code template, creating new branches, or creating/promoting `admin` or `manager` roles.
- `staff` — branch-scoped; can operate transactional flows (sale, draft, receiving, expense, petty cash) for assigned branches; cannot edit settings or `branch_inventory` cost/price/reorder; cannot delete docs
- `cashier` — branch-scoped; today-only sales reports (preserves current single-branch restriction, now applied per branch); same write boundaries as `staff`

### 3.5 Branched transactional collections (changed)

Add `branchId: string` field and a composite index on `(branchId, createdAt desc)` to each of:

- `sales`
- `drafts`
- `receivings`
- `expenses`
- `petty_cash`
- `user_logs`
- `price_history` (subcollection on products)

### 3.6 `stock_transfers/{transferId}` (new, v2 schema only — no UI in v1)

```
{
  id: string,
  fromBranchId: string,
  toBranchId: string,
  items: [{ productId, quantity, unitCost }],
  status: 'draft' | 'in_transit' | 'received' | 'cancelled',
  dispatchedAt: timestamp | null,
  receivedAt: timestamp | null,
  createdBy: string,
  notes: string
}
```

And `receivings` gains:
- `sourceType: 'purchase' | 'transfer'`
- `transferId?: string`

### 3.7 Sale counter (changed)

`settings/sale_counters` becomes keyed by `{branchId}_{date}` instead of `{date}`. Sale number format: `{branchCode}-{YYYYMMDD}-{seq}`, e.g. `BR01-20260511-001`.

### 3.8 Settings scoping

**Global** (`/settings/*` — admin-only write):
- Product categories
- Expense categories
- Payment method list
- Default tax rate
- Currency (single in v1)
- `cost_codes_template` — the default cost code mapping copied into new branches

**Per-branch** (`/branches/{branchId}/settings/*`):
- `cost_codes` — branch's active cost code mapping (seeded from template on creation, then independent)
- `tax_override` — optional rate override
- `receipt_config` — header/footer text, printer config

## 4. Security Rules (Firestore)

The rules are the only thing stopping a Branch B user from reading Branch A's data once we trust the schema. Discipline at this layer is non-negotiable.

### 4.1 Helpers

```js
function userDoc()       { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data; }
function isAdmin()       { return userDoc().role == 'admin'; }
function isManager()     { return userDoc().role == 'manager'; }
function isActiveUser()  { return userDoc().status == 'active'; }
function userBranches()  { return userDoc().assignedBranchIds; }
function hasBranch(b)    { return isAdmin() || b in userBranches(); }
function docBranch(d)    { return d.data.branchId; }
function incomingBranch(){ return request.resource.data.branchId; }
```

`hasBranch(b)` is the load-bearing primitive. Admins implicitly bypass branch checks.

### 4.2 Branched transactional docs

Applied to `sales`, `drafts`, `receivings`, `expenses`, `petty_cash`, `user_logs`, `stock_transfers`:

```
allow read:   if isActiveUser() && hasBranch(docBranch(resource));
allow create: if isActiveUser() && hasBranch(incomingBranch())
                && incomingBranch() == request.resource.data.branchId;
allow update: if isActiveUser() && hasBranch(docBranch(resource))
                && incomingBranch() == docBranch(resource);  // can't reparent
allow delete: if isAdmin() ||
              (isManager() && hasBranch(docBranch(resource)));
```

### 4.3 `branch_inventory/{branchId}_{productId}`

The doc ID must encode `branchId` so a client can't create a doc for a branch they don't have access to. Writes are split: stock-movement fields (touched by sale and receiving flows) are open to any branched user; settings-like fields (cost, price override, reorder level) require manager or admin.

```
function isStockMovementWrite() {
  return request.resource.data.diff(resource.data).affectedKeys()
    .hasOnly(['quantity', 'lastSoldAt', 'lastReceivedAt', 'updatedAt']);
}

allow read: if isActiveUser() && hasBranch(branchId);

allow create: if isActiveUser() && hasBranch(branchId)
                && incomingBranch() == branchId;
                // First stock-in (typically via receiving) creates the doc.
                // Later edits to cost/priceOverride/reorderLevel require manager+ per `allow update` below.

allow update: if isActiveUser() && hasBranch(branchId)
                && incomingBranch() == branchId
                && (isStockMovementWrite()
                    || isAdmin()
                    || (isManager() && branchId in userBranches()));

allow delete: if isAdmin();
```

### 4.4 `products` (global master catalog)

```
allow read:  if isActiveUser();
allow write: if isAdmin();
```

### 4.5 `branches`

Managers can update their branches' metadata (name, address, tax override, etc.) but cannot create new branches, change `status`, or delete branches — those remain admin-only.

```
function isBranchStatusChange() {
  return request.resource.data.diff(resource.data).affectedKeys().hasAny(['status']);
}

allow read:   if isAdmin() || branchId in userBranches();
allow create: if isAdmin();
allow update: if isAdmin() ||
              (isManager() && branchId in userBranches() && !isBranchStatusChange());
allow delete: if isAdmin();
```

### 4.6 `users`

Managers can read users whose assignments overlap their own, and can create/edit `staff` or `cashier` users assigned to branches the manager has. They cannot promote anyone to `manager` or `admin`, and cannot assign users to branches outside their own scope.

```
function targetRole()        { return request.resource.data.role; }
function targetBranches()    { return request.resource.data.assignedBranchIds; }
function isStaffOrCashier(r) { return r == 'staff' || r == 'cashier'; }
function changesPrivileged() {
  return request.resource.data.diff(resource.data).affectedKeys()
    .hasAny(['role','assignedBranchIds','status']);
}

allow read: if isAdmin() ||
            request.auth.uid == userId ||
            (isManager() && resource.data.assignedBranchIds.hasAny(userBranches()));

allow create: if isAdmin() ||
              (isManager() &&
               isStaffOrCashier(targetRole()) &&
               targetBranches().hasOnly(userBranches()) &&
               targetBranches().size() > 0);

allow update: if isAdmin() ||
              (request.auth.uid == userId && !changesPrivileged()) ||
              (isManager() &&
               isStaffOrCashier(resource.data.role) &&        // can't touch admins/managers
               isStaffOrCashier(targetRole()) &&              // can't promote to manager/admin
               targetBranches().hasOnly(userBranches()) &&    // can't grant outside scope
               resource.data.assignedBranchIds.hasOnly(userBranches())); // can't poach from outside scope

allow delete: if isAdmin();
```

Notes:
- A manager **cannot** unassign a user from a branch the manager doesn't have — `resource.data.assignedBranchIds.hasOnly(userBranches())` enforces that the user being edited was already wholly within the manager's scope. This prevents a manager at Branch A from removing a user from Branch B.
- Email/auth account creation in Firebase Auth is a separate concern. The Firestore rule above gates the user *document*. The auth account creation flow (Cloud Function or admin SDK) must enforce the same role/branch constraints.

### 4.7 Settings

**Global** `/settings/*`:
```
allow read:  if isActiveUser();
allow write: if isAdmin();
```

**Per-branch** `/branches/{branchId}/settings/{settingId}`:
```
allow read:  if hasBranch(branchId);
allow write: if isAdmin() ||
             (isManager() && branchId in userBranches());
```

This is the rule that grants branch managers the ability to edit their own branch's cost code mapping.

### 4.8 Stock transfers (v2)

When transfers ship, `stock_transfers` allows reads/writes if `hasBranch(fromBranchId) || hasBranch(toBranchId)` — so the destination branch can mark a transfer received without write access to the source.

### 4.9 Rule limits

- **Cross-doc invariants** (e.g., "this sale's `branchId` must match this device's session") cannot be enforced by rules. Client-side enforcement + audit logging only. Rules verify the branch is one the user has, not that it's the "right" one for the active session.
- **Concurrency on inventory** — rules do not prevent oversell when two terminals at the same branch decrement concurrently. Mitigated by `runTransaction` (already in current sale repo) and per-branch doc bounds.
- **`get()` budget** — Firestore rules have a 10-`get()` budget per request. The `hasBranch()` helper performs one `get()` on the user doc per evaluation; well under budget today, but monitor as fields grow.

## 5. Active Branch State (Client)

### 5.1 Resolution order

1. **On sign-in:** read `users/{uid}.assignedBranchIds`.
   - 0 branches → blocking screen "Your account isn't assigned to a branch. Contact admin."
   - 1 branch → auto-select, skip picker.
   - >1 branches → branch picker; selection persists to local storage (`activeBranchId`).
2. **On app start (returning user):** read persisted `activeBranchId`. Validate against fresh `assignedBranchIds` (assignments can change). If invalid or missing, re-prompt.
3. **Switch branch:** menu item available only when `assignedBranchIds.length > 1`. Switching clears in-memory caches and rebuilds providers.
4. **HQ "All branches" mode:** admin-only sentinel `activeBranchId == '__ALL__'`. Used by report screens. Transactional screens (sales, drafts, receiving, expenses) reject `__ALL__` and force a real selection.

### 5.2 Flutter

A `StateNotifierProvider<ActiveBranchNotifier, ActiveBranch>` exposes the current branch. It is the single source of truth across the app. Every repository method takes `branchId` as an explicit parameter — no implicit globals, no defaults — and providers that wire data pass it from `activeBranchProvider`:

```dart
final salesTodayProvider = StreamProvider((ref) {
  final branch = ref.watch(activeBranchProvider);
  return ref.watch(saleRepoProvider).watchTodaysSales(branchId: branch.id);
});
```

Switching branches automatically invalidates dependent providers.

### 5.3 Web admin (React)

`useActiveBranch()` hook backed by `localStorage`. Mirrors Flutter's resolution rules. Repositories under `web_admin/src/data/repositories/` get the same `branchId` parameter treatment.

### 5.4 Cart & in-progress state

Branch switching mid-session voids any in-progress cart, draft edit, or receiving in progress. A confirmation dialog appears before switching if there is non-empty state.

## 6. Repository / Provider Changes

### 6.1 Flutter repositories

Every branched repository gains `branchId` on every method:

- **`SaleRepository`** — `createSale`, `watchTodaysSales`, `getSalesReport`, `getProfitReport`, `getNextSaleNumber`. Sale transaction also decrements `branch_inventory` (not `products.quantity`).
- **`ProductRepository`** — catalog methods stay global. New `getStockFor(productId, branchId)`, `setReorderLevel(productId, branchId, level)`, `setBranchCost(productId, branchId, cost)`, `setPriceOverride(productId, branchId, price?)` operate on `branch_inventory`.
- **`DraftRepository`, `ReceivingRepository`, `ExpenseRepository`, `PettyCashRepository`, `ActivityLogRepository`** — `branchId` on every query and stamped on every write.
- **`BranchRepository` (new)** — `listBranches()`, `getBranch(id)`, `createBranch()` (also seeds per-branch settings from global template in one transaction), `updateBranch()`, `setUserBranches(userId, ids)`.
- **`SettingsRepository` (changed)** — split into `GlobalSettingsRepository` and `BranchSettingsRepository(branchId)`.

### 6.2 Web admin repositories

`FirestoreProductRepository`, `FirestoreSaleRepository`, etc. under `web_admin/src/data/repositories/` get the same treatment. New `BranchRepository` and `BranchInventoryRepository`.

### 6.3 Price resolution helper

```dart
double effectivePrice(Product p, BranchInventory? bi) =>
  bi?.priceOverride ?? p.defaultPrice;
```

Mirrored in TypeScript for web admin. Sale line items continue to snapshot the price at the moment of sale, so historical receipts stay correct when overrides change.

### 6.4 Cost code rendering

Cost-code display becomes `(cost, branchId)` aware:

```dart
String renderCostCode(double cost, String branchId, WidgetRef ref) =>
  encode(cost, ref.read(costCodeMappingProvider(branchId)));
```

`costCodeMappingProvider.family<String>` reads `/branches/{branchId}/settings/cost_codes`. Same shape in TypeScript for web admin. Every callsite of cost-code rendering must pass `branchId`. In `__ALL__` mode, each row decodes with its own branch's mapping (which produces visually distinct encodings per row — a feature, not a bug).

If a branch's `cost_codes` doc is missing at read time (defensive), the helper falls back to the global template. This should never happen in practice (creation flow writes the doc atomically with the branch).

## 7. UI Surfaces

### 7.1 Mobile (Flutter)

- **Branch picker screen** — full-screen on first login when `assignedBranchIds.length > 1`. Reused as modal when switching mid-session.
- **AppBar branch indicator** — chip on every screen showing active branch name. Tap opens picker (enabled only for multi-branch users). `All branches` is rendered with semantic color (per `feedback_color_discipline.md` — neutral by default, semantic color reserved for status; `All branches` qualifies as status).
- **Drawer additions** — `Switch branch` (multi-branch users only), `Branch management` (admin sees all branches and global settings; manager sees only their assigned branches and per-branch settings).
- **Reports screens** — admin gets a branch filter (single / multi / all). Existing per-role restrictions (cashier/staff = today only) preserved per-branch.
- **Sale flow, draft flow, receiving flow, expenses, petty cash** — no visible change beyond AppBar indicator. Active branch stamped implicitly on writes.
- **Receiving** (`receiving_history_screen.dart`) — list query gains branchId filter; no visual change in v1.
- **Branch management screens** — admin sees full list with branch creation, status changes, and the global cost-code template. Manager sees only their assigned branches, can edit branch metadata, per-branch settings (cost codes, tax override, receipt config), and create/edit `staff`/`cashier` users assigned to those branches. Both share the same screens with role-gated controls.
- **Edit-product** — split into two flows: "Edit catalog (HQ)" for global product fields like name/barcode/defaultPrice (admin only); "Edit branch pricing" for per-branch `cost`, `priceOverride`, and `reorderLevel` (manager or admin). Stock count is never manually edited here — it's driven by sales and receiving.

### 7.2 Web admin (React)

- **Branch selector** in top bar; persisted in localStorage.
- **Branches management page** — admin sees CRUD plus the global cost-code template; manager sees only their assigned branches and per-branch settings, no create/delete. Mirror of mobile.
- **User management page** — add `assignedBranchIds` multi-select; surface in user list. Admin sees all users; manager sees only `staff`/`cashier` users whose branches overlap theirs, can create/edit within their scope.
- **All existing pages** (products, sales, reports, dashboards) — gain branch context. Catalog stays global; stock/price views show columns per active branch, with breakdowns in `All` mode.
- **Consolidated dashboards** — admin-only `All branches` mode aggregates totals with per-branch breakdown panels.

### 7.3 Cross-cutting UX

- Cart-non-empty confirm dialog on branch switch.
- Empty-state copy on transactional screens that says "Select a single branch to record sales" if HQ admin is in `All branches` mode.

## 8. Phasing & Rollout

Pilot/dev only today, so we wipe existing data and start clean. On first boot, seed one branch `BR01 · Main Store` and assign all existing users to it.

### Phase 1 — Foundation (no business value, unblocks everything)

- `branches` collection
- `users.assignedBranchIds`
- active-branch provider (Flutter) + `useActiveBranch()` hook (React)
- Branch picker + AppBar indicator
- Branch management UI (mobile + web)
- Firestore Rules rewrite per Section 4
- Indexes on `(branchId, createdAt desc)`
- Seed `BR01` and assign all existing users on first boot

### Phase 2 — Catalog + inventory cut-over

- Remove `quantity` and `cost` from `products`
- Add `branch_inventory` collection
- Sale transaction decrements `branch_inventory`
- Receiving writes to `branch_inventory`
- Product list/detail screens read stock from `branch_inventory` for active branch
- Reorder-level alerts become per-branch

### Phase 3 — Per-branch pricing & cost

- `priceOverride` and `cost` fields on `branch_inventory`
- `effectivePrice` helper
- Edit-product flows split (catalog vs branch)
- Margin in reports uses branch cost + effective price
- Per-branch cost code mapping (Section 9 below)

### Phase 4 — HQ consolidation

- `All branches` admin mode (sentinel handling, read-only guards)
- Cross-branch dashboard and report views
- Branch filter on existing report screens
- Web admin consolidated dashboards

### Phase 5 — Transfers schema (v2 placeholder)

- `stock_transfers` collection + `receivings.sourceType` field
- Rules for `stock_transfers`
- No UI

## 9. Cost Code Mapping (cross-cutting)

Each branch has its own active cost code mapping. There is a global template for seeding new branches; once seeded, branch mappings are independent of the template.

- **`/settings/cost_codes_template`** (global, admin-only write) — HQ default. Editing the template does NOT propagate to existing branches.
- **`/branches/{branchId}/settings/cost_codes`** (per-branch) — active mapping. Seeded from template on branch creation. Editable by admin OR by a manager assigned to that branch.
- **Rendering helper** takes `branchId`. In `All branches` mode, each row decodes with its own branch's mapping.
- **Branch management UI** exposes a "Cost code mapping" subsection per branch.

## 10. Risks & Open Questions

### Risks

- **Race on `branch_inventory` doc** during concurrent sales at the same branch is still possible — bounded but real. Existing `runTransaction` pattern in sales handles it; we keep that and verify in tests.
- **Rule complexity** — every read/write fires `get()` on the user doc. Stays under Firestore's 10-`get()` budget today, but monitor as fields grow.
- **Cost code rendering callsites** — every place that renders cost codes today must pick up the new `(cost, branchId)` source. A grep-and-audit pass is part of Phase 3.
- **Branch switching state hygiene** — anything cached in providers must be invalidated cleanly on switch. Test path: switch branch mid-sale, mid-draft, mid-receiving.
- **`get()` on user doc per rule eval** — high-frequency reads (e.g., streaming sales list) re-evaluate rules per snapshot. Acceptable, but watch costs at scale.

### Open questions (resolve during implementation)

- Should the branch picker remember per-device or per-user-per-device? (Currently per-device via local storage.)
- Should cashier role also be allowed to view their branch's cost codes? (Currently yes, via `hasBranch` read on per-branch settings.)
- Tax override: when present on a branch, does it fully replace global tax or stack? (Currently: fully replaces.)

## 11. Acceptance Criteria

- A user with `assignedBranchIds: [A]` cannot read or write any document with `branchId: B`, verified by both rule unit tests and integration tests.
- A user with `assignedBranchIds: [A, B]` can switch between A and B without re-login; data in lists updates accordingly.
- Concurrent sales at Branch A and Branch B for the same product do not interfere (separate `branch_inventory` docs).
- A sale at Branch A produces sale number `BR01-YYYYMMDD-NNN`; a sale at Branch B the same day produces `BR02-YYYYMMDD-NNN`. No collision.
- HQ admin in `All branches` mode sees a dashboard summing all branches; switching to single-branch mode filters to that branch.
- A manager assigned to Branch A can edit Branch A's cost code mapping, tax override, branch metadata, and `branch_inventory` cost/price/reorder fields — but not Branch B's, and not the master product catalog, global settings, or the cost-code template.
- A manager can create `staff`/`cashier` users assigned to their branches but cannot create another `manager` or `admin`, and cannot assign users to branches outside their scope.
- A manager cannot edit or delete `manager` or `admin` user docs.
- A manager can delete transactional docs (sales, expenses, etc.) within their assigned branches; staff and cashier cannot.
- A manager cannot change a branch's `status` field (activate/deactivate is admin-only).
- Creating a new branch atomically copies the cost code template into the branch's settings.
- All transactional collections have a composite index on `(branchId, createdAt desc)` and queries that previously took N reads still take N reads.
