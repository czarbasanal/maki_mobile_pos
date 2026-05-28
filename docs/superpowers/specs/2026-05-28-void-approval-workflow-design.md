# Void approval workflow

Date: 2026-05-28
Status: Approved (design)

## Problem

Today a void is admin-only at every effective layer: the Firestore `sales`
update rule allows only admins, `VoidSaleUseCase` is reached only by the void
dialog, and `Permission.voidSale` is admin-only. But the "Void This Sale"
button in the sale-detail screen is shown to **every** role, so a cashier or
staff member can fill in a reason, re-enter their password, and only then hit a
`permission-denied` from Firestore — a confusing dead end. (A `canVoidSalesProvider`
exists but is unused, and `VoidSaleUseCase` never asserts a permission.)

Desired behavior: when a cashier or staff member taps void, it creates a
**request** that notifies admins and waits for approval. The actual void and
inventory restoration only happen once an admin approves.

## Constraints

- No Firebase Cloud Messaging and no Cloud Functions in the project (only
  `firebase_core` + `firebase_app_check`, plus auth/firestore/storage). So
  notifications are **in-app and real-time**, not push.
- Only an admin can write a void to Firestore (`sales` update is admin-only).
  So the actual void runs on the **approving admin's device**; there is no
  server to perform it.

## Decisions (from brainstorming)

1. Notify admins **in-app, real-time** via a notification bell — no push.
2. Requester experience is **non-blocking**: submit a reason, see a pending
   state on the sale, keep working. Result arrives asynchronously.
3. Admin **re-enters their password** to approve (keeps the existing
   destructive-action gate).
4. The approving **admin is recorded as `voidedBy`** on the sale; the request
   preserves the original requester. Activity log notes both.
5. Read/unread state for the bell is **shared across admins** (one `read` flag
   per request), not per-admin.
6. The bell's list and the approval queue are the **same screen**.

## Architecture

Standard clean-architecture layering, mirroring existing features
(entity → model → repository(+impl) → use cases → providers → screens).

### New collection: `void_requests/{id}`

| Field | Type | Notes |
|---|---|---|
| `saleId` | string | the sale to void |
| `saleNumber` | string | snapshot for display |
| `saleGrandTotal` | number | snapshot for display |
| `requestedBy` | string | requester uid |
| `requestedByName` | string | snapshot |
| `requestedByRole` | string | `cashier` / `staff` |
| `reason` | string | void reason (min 5 chars) |
| `status` | string | `pending` / `approved` / `rejected` |
| `read` | bool | bell read-state, default `false` |
| `createdAt` | timestamp | |
| `resolvedBy` | string? | approving/rejecting admin uid |
| `resolvedByName` | string? | snapshot |
| `resolvedAt` | timestamp? | |
| `rejectionReason` | string? | set on reject |

New: `VoidRequestEntity`, `VoidRequestModel`, `VoidRequestRepository` +
`VoidRequestRepositoryImpl`, and providers, all following the patterns used by
e.g. drafts/expenses.

### Request flow (cashier / staff)

`RequestVoidSaleUseCase.execute(actor, sale, reason)`:
1. `assertPermission(actor, Permission.requestVoidSale)`.
2. Validate `reason` (non-empty, ≥ 5 chars — same rule as the current void).
3. Reject if a `pending` request already exists for `saleId` (app-side query)
   → returns a "void already pending" failure.
4. Create the `void_requests` doc with `status: pending`, `read: false`,
   `requestedBy = actor.id`.

The sale document is not modified (cashier/staff cannot write `sales`). The
pending state is derived from the request, not stored on the sale.

### Pending indicator (sale detail, any viewer)

A live query of `void_requests` where `saleId == sale.id && status == pending`.
If present, the sale-detail screen shows a disabled "Void pending approval"
state instead of the void/request button.

### Notification bell + approval (admin)

- A bell icon with an unread-count badge in the **dashboard app bar**, shown to
  admins only (gated on `Permission.voidSale`).
- **Unread count** = live stream of `void_requests` where `read == false`.
- **Bell tap** → **Void Requests screen**: rows newest-first
  (requester · sale number · amount · time · status), unread rows marked. This
  screen is also the approval queue; `pending` rows are actionable.
- **Row tap** → request detail; marks that request `read`. For a `pending`
  request, the detail offers **Approve** and **Reject**.
- **Approve** → password dialog → `ApproveVoidRequestUseCase`:
  `assertPermission(admin, Permission.voidSale)`, run the existing
  `VoidSaleUseCase` (void + inventory restore) with `voidedBy = admin`, then set
  the request `status: approved`, `resolvedBy/Name`, `resolvedAt`. Order: void
  first; mark the request approved only after the void succeeds. (If the
  status write fails after the void succeeds, the sale is already voided and the
  request stays `pending`; the admin can re-open and it will show already-voided
  — acceptable, no data loss.)
- **Reject** → reason dialog → `RejectVoidRequestUseCase`:
  `assertPermission(admin, Permission.voidSale)`, set `status: rejected`,
  `rejectionReason`, `resolvedBy/Name`, `resolvedAt`. The sale is untouched.
- **Mark all as read** → batch set `read: true` on all requests → count resets.

### Requester sees the result

Via the same live `void_requests` query on the sale detail: pending badge clears
on resolution; if approved the sale now reads as voided; if rejected the
rejection reason is shown.

## Permissions

- Add `Permission.requestVoidSale` → granted to **cashier** and **staff**.
- `Permission.voidSale` stays **admin-only** (direct void + approve/reject).
- Wire the existing-but-unused `canVoidSalesProvider` to gate the admin
  direct-void button.
- Add `assertPermission(actor, Permission.voidSale)` to `VoidSaleUseCase`
  (requires threading the acting `UserEntity` into the use case) — closes the
  current gap where the use case relies only on the password + Firestore.

## Firestore rules — `void_requests/{requestId}`

```
match /void_requests/{requestId} {
  // Any active valid user can read (pending indicator + admin list).
  allow read: if isValidUser() && isActiveUser();

  // Requester creates their own pending request.
  allow create: if isValidUser() && isActiveUser()
    && request.resource.data.requestedBy == request.auth.uid
    && request.resource.data.status == 'pending';

  // Only admin resolves (approve/reject) or marks read.
  allow update: if isAdmin() && isActiveUser();

  // Audit trail — no deletes.
  allow delete: if false;
}
```

The `sales` update rule (admin-only) is unchanged — the destructive write still
only happens on an admin's device during approval.

## Audit

The voided sale records the approving admin as `voidedBy`/`voidedByName`. The
`void_requests` doc preserves `requestedBy`. The activity log entry for the void
notes both (e.g. "Voided SALE-0042 — requested by {cashier}, approved by
{admin}").

## UI summary

- **Sale detail**: admin → existing "Void This Sale" (direct, now gated by
  `canVoidSalesProvider`); cashier/staff with `requestVoidSale` and no pending
  request → "Request Void" → reason dialog; if a pending request exists (any
  role) → disabled "Void pending approval".
- **Dashboard**: admin-only notification bell + unread badge → Void Requests
  screen.
- **Void Requests screen** (admin): list + "Mark all as read"; row → request
  detail with Approve (password) / Reject (reason).
- New route for the Void Requests screen, guarded by `Permission.voidSale`.

## Testing

**Firestore rules suite** (`tools/firestore-rules-test`):
- create: cashier/staff/admin can create their own pending request; create
  denied when `requestedBy != auth.uid`, when `status != 'pending'`, and for
  inactive users.
- read: active valid users can read; unauthenticated denied.
- update: admin can update (approve/reject/mark-read); cashier/staff denied.
- delete: denied for everyone.
- `sales` update remains admin-only (regression check).

**Use-case unit tests** (`mocktail`):
- `RequestVoidSaleUseCase`: permission (cashier/staff allowed, admin path
  irrelevant), reason validation, dedupe (existing pending → failure), success
  creates a pending request.
- `ApproveVoidRequestUseCase`: admin-only; runs the void and marks approved;
  non-admin denied; if the void fails, request stays pending.
- `RejectVoidRequestUseCase`: admin-only; marks rejected with reason; sale
  untouched.
- `VoidSaleUseCase`: now asserts `voidSale` (admin allowed; cashier/staff
  denied).

**Permission-model test**: `requestVoidSale` is true for cashier and staff and
false for admin; `voidSale` is true only for admin.

**Manual UI verification** (no widget-test harness): request as cashier/staff,
pending badge appears; admin bell shows count; approve with password voids the
sale and restores stock; reject shows reason; mark-all-as-read resets the count.

## Out of scope

- Push / background notifications (no FCM/Functions).
- Per-admin read state (shared flag is sufficient for now).
- Notifications for event types other than void requests.
- Requester-side push when resolved (they see it via the live sale view).
- Time-limit / auto-expiry of pending requests.
