# Job Orders (repurpose Drafts) — Design

**Date:** 2026-07-01
**Surface:** Mobile (Flutter) only — v1
**Status:** Design revised after code-recon (in-ticket parts + safe bill-out added); pending final spec review → implementation plan

---

## Plain-language summary

Motorcycles come into the shop for service. Today the cashier has no clean way to
hold an open job while parts and labor pile up over the hour. This turns the existing
**Drafts** feature into **Job Orders**: the cashier opens a job order for a bike,
labels it (customer / plate), picks the motorcycle model, and — once a mechanic takes
it — assigns the mechanic. Parts and labor get added to that job order while the
service runs — right on the ticket, without tying up the register, so walk-in buyers can
still be rung up in parallel. When the bike is done, the cashier **bills out** the job
order: it becomes a normal sale and the ticket is marked done.

Walk-in buyers who just grab an item are **unaffected** — they keep using the normal
quick checkout with no job order, no bike, no mechanic.

Two new owner reports answer the questions that motivated this:
- **Motorcycle Models** — which bikes we service most often.
- **Top Mechanics** — who is bringing in the most revenue.

## Why this shape

The current `DraftEntity` already stores `items`, `laborLines`, `mechanicId`/
`mechanicName`, so the *data* is most of a service ticket, and adding/updating **labor +
mechanic** on an open draft already persists in place. New work falls in three areas:
the **motorcycle model** field, the **reporting**, and — the part code-recon surfaced —
making a ticket **hold parts safely over time**. Today the only way to add parts to a
saved draft is "Edit in POS," which loads it into the one shared register cart and
**deletes the saved draft** until re-save; that both ties up the register (blocking
parallel walk-in sales) and opens a data-loss window. Since parts get added "a mix of
both" — incrementally and at bill-out — v1 adds in-ticket part editing and a
non-destructive bill-out (see "Ticket persistence" below). Still additive, no new
module — but Phase C is larger than a pure rename.

---

## Decisions (locked)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Structure | **Repurpose** drafts → Job Orders (one concept). Not a separate parallel module. |
| 2 | Name (user-facing) | **"Job Orders"** (the old "Drafts" label). |
| 3 | Motorcycle model capture | **Pick-or-add hybrid** — managed `motorcycle_models` list + inline add, normalized on add. |
| 4 | Ticket label | **Reuse the existing required `name` field**, relabelled "Customer / plate". No new identifier fields. |
| 5 | Model requiredness | **Required only to bill out** a Job Order (optional while the ticket is open). Walk-in sales never require it. |
| 6 | Mechanic "top" ranking | **Total revenue (parts + labor)** on their jobs; job count + labor shown as columns. |
| 7 | Scope | **Mobile only** (v1). Web keeps generic drafts; parity is a future follow-up. |
| 8 | Report data source | **Completed, non-voided sales** for the selected period (realized work), reusing the shared preset date filter. |
| 9 | Report visibility | **Owner/admin only** — gated like the Profit report (both new reports). Cashiers don't see them. |
| 10 | Parts on an open ticket | **Edited in-ticket** — product search/scan appends parts to the ticket (plus editable qty / remove), saved in place; the shared register cart is never used to accumulate a ticket. |
| 11 | Creating a ticket | A cart-independent **"New Job Order"** entry (label + model + mechanic; parts optional) so a bike arriving mid-walk-in never fights the one shared cart. POS "Save as Job Order" stays as a secondary path (turn the current cart into a ticket). |
| 12 | Bill-out | **Non-destructive** — billing out marks the ticket **converted** only on a *successful* sale (reusing the existing, currently-dead `_reconcileDraft` / `markDraftAsConverted` path); no delete-on-load. Sale carries the ticket's `draftId` + `motorcycleModel`. Drops the destructive "Edit in POS". |

## Goals

- Rename the Drafts experience to Job Orders on mobile (labels, titles, buttons, dialogs).
- Add a motorcycle model to a Job Order via pick-or-add; snapshot it onto the sale at bill-out.
- Require the model to bill out a Job Order (not to open one, not for walk-in sales).
- Ship two reports: Motorcycle Models (by job count) and Top Mechanics (by total revenue).

## Non-goals (v1)

- No web-admin changes (web keeps its generic drafts; same shared `drafts` collection).
- No rename of the `drafts` Firestore collection or the Dart `Draft*` code symbols
  (see "Rename is skin-deep" below).
- No structured plate / customer-contact fields (parked; the single label field covers it).
- No separate/cart-independent payment UI for bill-out — it reuses the existing checkout
  screen via the register cart (guarded when the cart is busy).
- No model prompt on walk-in / no-ticket service sales (they simply won't appear in the
  Models report — acceptable; revisit later if needed).
- No mechanic time-in/out, downpayment, or delivery fees (roadmap §24/§27, still parked).

---

## Rename is skin-deep (on purpose)

Rebrand only what the cashier **sees**; keep the data + code names underneath.

- **Keep** the `drafts` Firestore collection, `DraftEntity`/`DraftModel`, providers,
  usecases, and the internal `/drafts` route. **Why:** the web admin still reads/writes
  that same `drafts` collection — renaming it would break web and force a risky data
  migration for zero shop benefit. It also keeps this change small and reversible.
- **Change** user-facing strings: nav entry, screen titles ("Drafts" → "Job Orders"),
  the save action ("Save as draft" → "Save job order"), list/detail/dialog copy
  ("Delete draft?" → "Delete job order?"), empty states, and the `name` field label
  ("Draft name" → "Customer / plate").

A short internal note will document that **Job Order == draft** so future readers aren't
confused by the code/UI naming gap.

---

## Data model changes

### 1. `motorcycleModel` on Draft and Sale (optional string)

Add a nullable `motorcycleModel` field to:

- `DraftEntity` / `DraftModel` (+ `props`, `copyWith`, `toMap`/`fromMap`, `toEntity`/`fromEntity`, `create`).
- `SaleEntity` / `SaleModel` (+ same surfaces) — this is the **durable snapshot** the
  Models report reads.

Optional everywhere at the data layer → old drafts, old sales, and web-created drafts
keep deserializing (missing field → `null`). The value stored is the **canonical model
name** (the normalized display name from the `motorcycle_models` list).

The model must travel **Draft → cart → Sale** at bill-out. `loadFromDraft` carries it
into `CartState` (alongside `mechanicId`/`mechanicName` and a now-set `sourceDraftId`),
and `toSale` writes it onto the `SaleEntity`. The bill-out **gate lives in the ticket
editor**: the draft's `motorcycleModel` must be set before bill-out (walk-in checkout,
which has no ticket, never hits the gate).

### 2. New `motorcycle_models` managed collection

Mirror the `mechanics` data layer (`MechanicEntity`/`Model`/`Repository`/`RepositoryImpl`/
remote datasource/provider), scaled down:

```
MotorcycleModelEntity {
  String id;
  String name;            // canonical display, e.g. "Nmax"
  bool   isActive;        // soft-delete; inactive drops from picker, stays valid on history
  DateTime createdAt;
  DateTime? updatedAt;
  String? createdBy;
  String? updatedBy;
}
```

Firestore collection `motorcycle_models`, one doc per model. Add the constant to
`lib/core/constants/firestore_collections.dart`.

**Normalization + dedup (pick-or-add):** on inline add, normalize the typed text
(trim + collapse internal whitespace) and do a **case-insensitive match** against
existing active models. If a match exists, reuse it (no new doc); otherwise create a
new doc with the normalized display text. This gives pick-or-add convenience without
forking the frequency counts ("nmax" snaps onto "Nmax"). Reuse the same
name-matching approach suppliers/mechanics already use.

---

## Firestore rules (one addition — confirm before deploy)

New block for `motorcycle_models`. **Diverges from `mechanics`** because pick-or-add
requires a *cashier* (non-admin) to create a model on the fly:

```
match /motorcycle_models/{modelId} {
  allow read:   if isValidUser() && isActiveUser();                 // picker streams active models
  allow create: if isValidUser() && isActiveUser();                 // cashier inline add (like /drafts)
  allow update, delete: if isAdmin() && isActiveUser();             // Settings cleanup / rename / deactivate
}
```

No new composite index — reporting groups client-side over the period's sales (see below).
This is a `firestore.rules` change → **production-affecting; confirm with owner before deploy**
(per CLAUDE.md).

---

## Ticket persistence & the shared register cart

**The problem (from code-recon).** The app has **one** register cart (`cartProvider`).
A draft's labor/mechanic can be edited in place, but its **items are read-only** in the
draft editor — the only way to add parts is "Edit in POS," which `loadFromDraft` into the
shared cart and then **immediately deletes the draft** (all three resume paths do this).
Also `CartState.sourceDraftId` is never set, so `isFromDraft` is dead, sales never carry a
`draftId`, and the built-but-unused `markDraftAsConverted` conversion never runs. Net
effect for a service shop: you can't add parts to a ticket without commandeering the
register (so you can't ring a walk-in at the same time), and an interrupted edit loses the
ticket.

**The resolution (v1).**
- **In-ticket parts.** The Job Order editor gains an "Add parts" action (reuse the POS
  product search + barcode scan) plus editable quantity / remove, persisted to the draft
  via the existing full `updateDraft` path. The register cart is not involved.
- **Cart-independent creation.** A "New Job Order" action creates the ticket (label +
  model + mechanic; parts optional) and opens the editor — no cart needed.
- **Non-destructive bill-out.** "Bill out" sets `sourceDraftId` on the loaded cart (so the
  sale carries `draftId`) and does **not** delete on load; the existing `_reconcileDraft`
  marks the ticket **converted** only after the atomic sale write succeeds. An abandoned
  bill-out leaves the ticket intact. Converted tickets drop off the active list (filtered
  by `isConverted == false`) and remain as an audit link.
- **Cart-busy guard.** If the register cart already holds an unfinished walk-in sale,
  bill-out warns before loading the ticket (so it never silently clobbers a sale in
  progress).
- **Remove "Edit in POS."** Redundant once parts are editable in-ticket; removing it
  deletes the destructive path entirely.

**Idempotency note.** Resurrecting `sourceDraftId` + a `draftId` on the sale rides the
existing checkout-id idempotency (the sale write is already guarded); conversion is
best-effort *after* the guarded write, exactly as `_reconcileDraft` was designed. We do
**not** change the sale-write transaction.

---

## Job Order flow (mobile)

1. **New Job Order** — a "New Job Order" action (FAB on the Job Orders list) opens a
   create dialog capturing **Customer / plate** (required label), **Motorcycle model**
   (pick-or-add; optional here), and **Mechanic** (optional), then opens the ticket
   editor. No register cart involved. (Secondary path: from the POS cart, "Save as Job
   Order" turns the current cart into a ticket, as today.)
2. **List** — the Job Orders list (old drafts list) shows label, model, mechanic, item
   count, and total; excludes converted tickets.
3. **Work the ticket (editor)** — add parts (search/scan → appended to the ticket), edit
   quantity / remove, add/edit labor, assign/update mechanic, set the motorcycle model and
   label. Every change persists in place via `updateDraft`. The register stays free for
   walk-ins throughout.
4. **Bill out** — "Bill out" from the editor. **Gate:** the ticket's `motorcycleModel`
   must be set (block with a clear prompt otherwise). The ticket loads into the cart with
   `sourceDraftId` set and goes to the existing checkout/payment screen; on a successful
   sale the model is written onto the `SaleEntity`, the sale carries `draftId`, and
   `_reconcileDraft` marks the ticket converted. Walk-in sales (no ticket) are unaffected
   and never see the model gate.

**Existing rule preserved:** labor still requires a mechanic (labor-only blocked). The
model gate is independent and applies only to Job Order bill-out.

---

## Reporting

Both reports read **completed, non-voided sales** for the selected period (reuse the
Reports hub's existing preset date filter and sales loader). All grouping is client-side
→ **no new Firestore index**. Both support CSV export (reuse `report_csv` /
`saveReportCsv`), matching the other reports.

### Aggregation helpers (mirror `lib/core/utils/labor_report.dart`)

- **`motorcycleModelReportFromSales(sales)`** → per-model rows: `jobCount` (primary sort,
  desc), `totalRevenue` (Σ `grandTotal`), `laborTotal`. Sales with no `motorcycleModel`
  fall into an **"Unspecified"** bucket (transitional — historical/pre-feature sales).
  Ties broken by model name asc.
- **`mechanicPerformanceReportFromSales(sales)`** → per-mechanic rows: `totalRevenue`
  (Σ `grandTotal`, **primary sort, desc** — decision #6), `jobCount`, `laborTotal`.
  Only sales with a `mechanicId` are included; ties broken by name asc. (This is distinct
  from the existing Labor report, which is labor-only and ranked by labor.)

### Surfacing

Add one **"Job Orders"** card to the Reports hub (`reports_hub_screen.dart`) opening a
screen with two views — **Motorcycle Models** and **Top Mechanics** (segmented control
or two sub-cards; final choice at plan time). Keeps the hub tidy and the existing
**Labor** report untouched.

**Visibility:** **owner/admin only** (decision #9) — gated like the Profit report:
a permission check hides the hub card for non-admins **and** a route guard blocks the
Job Orders reports screen. Reuse the existing `viewProfitReports` permission, or add a
dedicated `viewJobOrderReports` — decide at plan time (default: reuse `viewProfitReports`).
Gating a mobile screen touches three places (nav/hub card + `route_names`/`app_routes` +
`route_guards.dart`); miss one and the guard redirects — plan must hit all three.

---

## Back-compat & migration

- `motorcycleModel` optional at the data layer → no migration; old drafts/sales and
  web-created drafts deserialize fine (field absent → `null`).
- Web is untouched and keeps writing generic drafts to the shared `drafts` collection;
  mobile tolerates a null model. Web ignores the extra `motorcycleModel` field on drafts/
  sales (converters read named fields). *Verify* the web Draft/Sale converters don't
  choke on an unknown field (they shouldn't).
- Historical completed sales have no model → they show under "Unspecified" in the Models
  report and are simply absent of a bike; mechanic report includes any historical sale
  that already had a mechanic.

---

## Testing (TDD — write failing tests first)

- **Entity/model round-trips:** Draft and Sale serialize/deserialize `motorcycleModel`
  (present + absent); `copyWith`/`props` include it.
- **`MotorcycleModel` data layer:** entity/model round-trip; repository create/list/
  update/deactivate.
- **Normalization + dedup:** "  nmax " and "Nmax" resolve to the same canonical model;
  new name creates one doc.
- **In-ticket parts:** adding a part appends to the draft and persists (`updateDraft`);
  editing qty / removing persists; the register cart is untouched.
- **Bill-out gate:** bill-out with an empty `motorcycleModel` is blocked; with it set, the
  model + `draftId` reach the written sale; walk-in checkout has no gate.
- **Non-destructive convert:** a successful bill-out marks the ticket `isConverted` (via
  `_reconcileDraft`) and drops it from the active list; a failed/abandoned bill-out leaves
  the ticket intact and unconverted.
- **Aggregations:** `motorcycleModelReportFromSales` (job-count sort, Unspecified bucket,
  voided excluded) and `mechanicPerformanceReportFromSales` (total-revenue sort, no-
  mechanic excluded, voided excluded), including CSV row shaping.
- **Widget smoke:** Job Orders list/dialog render with new labels; Reports "Job Orders"
  screen renders both views.

Run `flutter test` + `flutter analyze` and confirm green before "done"
(verification-before-completion).

## Rollout

- Deploy the `motorcycle_models` rules block (**confirm with owner first**).
- No new Firestore index.
- Mobile release per project process: debug-signed `flutter build apk --release` +
  manual `adb install -r` on shop devices (agent can build, not install/smoke). Bump
  version. Enforcement of the model gate + pick-or-add is only live once the APK is
  installed.

---

## Risks & open questions

- **Two mechanic reports** (existing Labor vs new Top Mechanics) could confuse. Mitigated
  by bundling the new ones under a distinct "Job Orders" section and keeping Labor as-is.
  *Open:* is that separation clear enough, or should Labor eventually fold in?
- **Cashier-created model docs** are a minor abuse surface (spam), same trust level as
  creating drafts/sales; normalization limits accidental dupes. Acceptable.
- **Persistence change** (destructive resume → in-ticket parts + convert-on-success)
  touches the draft/cart flow, not the guarded sale-write transaction. Risk is contained
  to the ticket editor + bill-out handler; covered by the convert/abandon tests above.
- **Bill-out still uses the shared cart** for payment (reusing the checkout screen). The
  cart-busy guard prevents clobbering an active walk-in; a fully cart-independent payment
  UI is deliberately out of scope for v1.
- **Model-less service sales:** quick services without a Job Order won't carry a model
  and won't appear in the Models report. Acceptable for v1; a future option is an optional
  model field on POS service sales.
- **Report visibility:** ~~all-users vs admin-only~~ **Resolved — owner/admin only**
  (decision #9). Gated like Profit; watch the three-place mobile route-guard gotcha above.

## Out of scope / future

- Web parity (repurpose drafts → Job Orders on the web admin, with the same reports).
- Structured plate + customer contact fields; search by plate/customer.
- Optional model on walk-in service sales.
- Mechanic time-in/out (§24), downpayment + delivery fees (§27).
