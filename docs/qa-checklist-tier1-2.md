# Tier 1 + Tier 2 manual QA checklist

A walkthrough you can run through against the live app to verify the
mission-critical (Tier 1) and financial-integrity (Tier 2) requirements
across the three roles. Each item names the role(s) that should be exercised
and the expected outcome — including what should be **denied** for the wrong
role, since negative cases are how RBAC bugs hide.

If you're short on time and just want green/red signal, the items marked
**[BLOCKER]** are the ones that block release.

---

## Pre-flight

Have the following ready before you start:

- [ ] One Firebase user per role: `admin@…`, `staff@…`, `cashier@…`. Each
      `users/{uid}` doc must have the matching `role` field and `isActive: true`.
- [ ] At least 5 active products in `products/` with cost + price set, mixed
      stock levels (one product with `quantity: 0`, one near `reorderLevel`).
- [ ] A known petty-cash opening balance (note the figure before testing).
- [ ] One supplier created (so receiving can pick it up).
- [ ] A cost-code mapping configured (so cost obfuscation works).
- [ ] Browser dev tools open on the **Network** + **Console** tabs to spot
      Firestore permission-denied errors that the UI swallows.

For each role-specific scenario, sign in fresh — don't reuse a session,
because cached state can mask gating bugs.

---

## Tier 1 — Mission-critical

### T1.1 Authentication & session [BLOCKER]

| # | Scenario | Role | Expected |
|---|---|---|---|
| 1 | Sign in with valid credentials | Admin / Staff / Cashier | Lands on dashboard; no console errors. |
| 2 | Sign in with wrong password | Any | In-form error message ("Invalid credentials" or similar), no navigation. |
| 3 | Sign in with disabled user (`isActive: false` in Firestore) | Any | Either rejected at login or immediately bounced from any protected route. **Confirm** no protected screen renders before redirect. |
| 4 | Refresh the browser/app while signed in | Any | Stays signed in, lands on the same route. |
| 5 | Sign out from user menu (web) / settings (mobile) | Any | Returns to `/login`; back button doesn't restore the session. |
| 6 | Non-admin signs in on **web** | Staff / Cashier | Bounced to `/access-denied` (web is admin-only by design). Verify both staff and cashier hit this. |
| 7 | Forgot Password → email | Any | Reset email arrives; new password works on next sign-in. |

Edge cases:
- [ ] Tab open in two browser windows. Sign out in one — the other should
      lose access on next route navigation (or sooner).
- [ ] Network drops during sign-in: error is surfaced, not a silent hang.

### T1.2 POS — process a sale [BLOCKER]

Run this entire scenario as **each** of cashier, staff, and admin.

Setup: cart empty, register on `/pos`.

| # | Step | Expected |
|---|---|---|
| 1 | Search a product by name | Result appears with name, SKU, current price, in-stock count. |
| 2 | Search by exact SKU | Same product surfaces. |
| 3 | Search by an SKU variation (case / leading-zero / prefix change per `handle_sku_variation_usecase`) | Still resolves. |
| 4 | Add product to cart | Cart line shows price, qty 1, line total. |
| 5 | Adjust qty to 3 | Line total = unit price × 3. Subtotal updates. |
| 6 | Add a second product | Cart shows both lines, subtotal sums correctly. |
| 7 | Remove first item | Line vanishes, subtotal recalcs. |
| 8 | Tap **Checkout** | Goes to checkout screen with the same cart. |
| 9 | Pay cash with exact amount | Change = 0. |
| 10 | Pay cash with overpay | Change = tendered − total, never negative. |
| 11 | Pay GCash (or other non-cash method) | No change line; sale finalises. |
| 12 | Try to finalise with under-payment | Blocked with a clear error. |
| 13 | Successful finalise | Sale persists in Firestore (`sales/{id}`), cart clears, receipt screen shows correct items + payment. |
| 14 | After finalise: re-open the sale via Reports → Sale Detail | Same totals, same items, same payment method. |

[BLOCKER] specifically: items 1, 4, 9, 12, 13.

### T1.3 Stock decrement on sale [BLOCKER]

- [ ] Note the `quantity` of product P before sale.
- [ ] Sell 2 of P, finalise.
- [ ] Re-open the inventory list. Quantity is now `before − 2`.
- [ ] **Out-of-stock guard**: take a product with `quantity: 1`, open two POS
      tabs, add it in both, finalise both quickly. Exactly one should succeed;
      the other should fail with an out-of-stock error (not silently let
      qty go negative). Inspect Firestore — `quantity` should be 0, never -1.

### T1.4 Drafts [BLOCKER]

| # | Role | Step | Expected |
|---|---|---|---|
| 1 | Cashier | Build a 3-line cart, save as draft with a name | Draft appears on `/drafts` list with line count + saved-at timestamp. |
| 2 | Cashier | Open the draft, add a 4th line, save again | List reflects updated line count; created-by field still says cashier. |
| 3 | Cashier | Delete the draft | Removed from list. |
| 4 | Staff | Sees and can edit the cashier's draft | Per current rules, drafts are user-scoped — confirm what you actually want. The rules file allows admin to update/delete any. |
| 5 | Admin | Open + delete any draft | Allowed. |
| 6 | Cashier | "Resume" a draft → POS | Cart populates, prices are **revalidated** (if cost/price changed since save, the resumed cart should use *current* product price, not stale snapshot). |

Edge case:
- [ ] Resume a draft whose product was deleted: graceful error, not a crash.

### T1.5 Offline tolerance

- [ ] Open POS, build a cart, then disable network.
- [ ] Offline banner appears at the top of the shell (web) / above app body (mobile).
- [ ] Finalise the sale.
- [ ] Cart clears, receipt shows. Sale shows up in `/reports` after a moment.
- [ ] Re-enable network. Banner disappears. Inspect Firestore — sale is now
      remote.
- [ ] Sign out / sign back in offline: confirm cached auth state still lets
      the user in (or fails gracefully — depends on Firebase Auth offline
      behavior; document what actually happens here).

### T1.6 Role-specific access (Tier-1 negative cases) [BLOCKER]

For each, the role should **not** be able to reach the page or the action.
The router should redirect, **and** the screen widget should not render
anything mounted before redirect.

| # | Restricted action | Cashier | Staff | Admin |
|---|---|---|---|---|
| 1 | Open `/users` | Denied | Denied | Allowed |
| 2 | Open `/suppliers` | Denied | Denied | Allowed |
| 3 | Open `/petty-cash` | Denied | Denied | Allowed |
| 4 | Open `/logs` | Denied | Denied | Allowed |
| 5 | Open `/inventory/edit/:id` price field | Denied (no edit) | Visible but disabled | Editable |
| 6 | Open `/receiving` | Denied | Allowed | Allowed |
| 7 | Open `/reports/profit` | Denied | Denied | Allowed |
| 8 | Open `/settings/cost-codes` | Denied | Denied | Allowed |

For each "denied" row: deep-link the URL directly in the address bar (web) /
push the route programmatically (mobile) — the redirect must still kick in.

---

## Tier 2 — Financial integrity

### T2.1 Apply discount [BLOCKER]

| # | Role | Step | Expected |
|---|---|---|---|
| 1 | Cashier | Apply ₱10 amount discount to a ₱100 line | Line shows discount, subtotal reflects ₱90. |
| 2 | Cashier | Apply 15% discount to whole cart | Cart subtotal = sum × 0.85. |
| 3 | Cashier | Try to apply discount > line total | Blocked or capped at 100%; never produces a negative line total. |
| 4 | Cashier | Try to apply discount with non-numeric / negative input | Validation error, no application. |
| 5 | Admin | Same flows | Same outcomes. |
| 6 | Any | Finalise sale with discount | Sale doc records the discount amount and method. |
| 7 | Any | Reports show discount in the totals | Sale list shows discounted total; sales report aggregates discounts separately. |

### T2.2 Void sale (admin only, password gate) [BLOCKER]

| # | Role | Step | Expected |
|---|---|---|---|
| 1 | Admin | Open recent sale → tap **Void** | Password confirm dialog appears. |
| 2 | Admin | Enter wrong password | Rejected; sale remains active. |
| 3 | Admin | Enter correct password | Sale status becomes `void`. |
| 4 | Admin | Voided sale: stock is **returned** to inventory | Quantity of each line product = pre-sale quantity. Verify in Firestore. |
| 5 | Admin | Voided sale appears in reports with VOID badge, **excluded** from revenue totals (or shown in a separate column — confirm what the report intends). |
| 6 | Cashier | Try to void via UI | Button absent / disabled. |
| 7 | Staff | Same | Button absent / disabled. |
| 8 | Cashier or Staff | Try to void by hand-crafting a Firestore update | Rules reject (run a quick Firestore Rules Playground assertion if practical). |
| 9 | Activity log | Each void writes a log entry: user, sale id, before/after status, timestamp | Verify on `/logs`. |

### T2.3 Petty cash in / out (admin) [BLOCKER]

Setup: note opening balance from `/petty-cash`.

| # | Step | Expected |
|---|---|---|
| 1 | As admin, record a Cash In of ₱1,000 with a note | New entry, balance = opening + 1000, note persists. |
| 2 | As admin, Cash Out of ₱200 | Balance decremented by 200. |
| 3 | Try Cash Out > current balance | Blocked with a clear error (don't go negative). |
| 4 | As staff, navigate to `/petty-cash` | Denied (router redirect). |
| 5 | As cashier, same | Denied. |
| 6 | Refresh — balance survives across reload (read from Firestore aggregate, not local). |
| 7 | Activity log shows each entry with actor, amount, direction, note. |

### T2.4 Day-end cut-off [BLOCKER]

| # | Step | Expected |
|---|---|---|
| 1 | As admin, ensure today's sales are present | Sales exist. |
| 2 | Run cut-off | Dialog requests counted cash, displays expected vs counted, computes discrepancy. |
| 3 | Submit cut-off | Day is **locked** in Firestore (whatever flag/marker the use-case writes); subsequent sales for that "business date" should warn or be rejected per design. **Confirm** the actual behavior — this can drift from intent. |
| 4 | Try a second cut-off for the same day | Either blocked or treated as a re-cut (depends on use-case spec — verify and document). |
| 5 | After cut-off, the figures show in reports as that day's closing snapshot. |
| 6 | Staff / cashier cannot trigger cut-off | Action button absent. |

Critical edge case:
- [ ] Sale finalised at 23:59:55, cut-off at 00:00:05. Which "business day"
      does the sale belong to? Document and confirm reports agree.

### T2.5 Calculate change (cash payment edge cases) [BLOCKER]

For each, in POS as **cashier**:

| # | Total | Tendered | Expected change |
|---|---|---|---|
| 1 | 100.00 | 100.00 | 0.00 |
| 2 | 99.99 | 100.00 | 0.01 |
| 3 | 100.00 | 99.99 | Underpayment — finalise blocked. |
| 4 | 0.00 | 0.00 | Allowed if cart is empty? Should not be allowed; finalise requires ≥ 1 line. |
| 5 | 1234.56 | 2000.00 | 765.44 (no float drift). |
| 6 | 100.00 | 100,000.00 (typo) | Either accepted with huge change, or capped. **Confirm** what the UI does — large overpay is a common mis-entry. |
| 7 | Discounted line: 100 − 30% = 70, tendered 100 | Change 30. |

### T2.6 Expenses

| # | Role | Step | Expected |
|---|---|---|---|
| 1 | Cashier | Add an expense with category + amount + note | Created; appears in list. |
| 2 | Cashier | Try to edit own expense | **Denied** (`addExpense` only — no edit). Confirm the UI hides the edit affordance and any direct-route attempt is rejected. |
| 3 | Cashier | Try to delete an expense | Denied. |
| 4 | Staff | Same as cashier (add only) | Same outcomes. |
| 5 | Admin | Add, edit, delete expense | All allowed. |
| 6 | Admin | Edit cashier-created expense | Allowed; activity log records the edit. |
| 7 | Reports / dashboard | Today's expenses surface in summaries (if the dashboard shows them) | Verify per design. |

---

## Cross-cutting checks

Run these once at the end (any role appropriate per item):

- [ ] **Permission gate alignment**: pick three Tier-2 actions (void sale,
      cash-out, edit cost code). For each, confirm UI + use-case + Firestore
      rule all agree. The rule is the only one that matters under attack.
- [ ] **Activity log coverage**: every Tier-1 and Tier-2 state-changing action
      writes a log entry with actor, action, target id, before/after where
      meaningful. Spot-check 5 random items in `/logs` after this run.
- [ ] **Currency**: every screen showing money uses `₱` (or whatever the
      configured currency is) with 2 decimals — no `$`, no missing decimals,
      no `NaN` if a value is null.
- [ ] **Console errors**: with dev-tools open, the entire walkthrough should
      produce **no** Firestore permission-denied errors and **no** uncaught
      exceptions. Even if the UI looks fine, a swallowed permission error
      means a rule mismatch.
- [ ] **Refresh resilience**: at three points during the walkthrough, hit
      browser refresh (`Ctrl/Cmd+R`). State should restore correctly without
      re-login (auth survives), and any in-progress draft must be
      retrievable.

---

## Reporting results

For each row that fails, capture:

1. **Role** running the test
2. **Browser + OS** (web) or **device** (mobile)
3. **Steps to reproduce** (just the step numbers from this checklist + any deviation)
4. **Expected vs observed**
5. **Console / Firestore error** if any
6. **Screenshot** if visual

Group failures by tier. Tier 1 + any Tier 2 financial-integrity failure
blocks release; everything else queues into the next sprint.
