# Backlog — web admin receiving, void notifications, closing day, job orders

**Reported:** 2026-08-28, dictated by the shop owner.
**Status:** none started. Triage below is from a read of the code on the day,
marked CONFIRMED where the cause was found and HYPOTHESIS where it was not.

Ordered by risk, not by the order they were reported.

---

## 1. Receiving drafts lose items when two devices work at once — DANGEROUS

> "my saved as draft items suddenly vanish like some of them and only some
> gets successfully received … it happened when I opened on tablet and laptop
> at the same time then do different simultaneous receivings"

**Impact: silent stock loss.** Items believed received are not, and nobody is
told. This outranks everything else in this file.

**HYPOTHESIS — not yet confirmed.** Leads, strongest first:

- `executeReceivePlan` **mutates `plan.items` in place** (it stamps allocated
  SKUs back onto them) and its own doc comment warns: *"Callers persisting
  `plan.items` must do so AFTER this returns."* A caller that snapshots or
  persists the items before the transaction resolves would write a stale list.
  Start here.
- The draft document is likely written whole rather than field-merged, so two
  tabs holding different in-memory copies of the same draft would give
  last-write-wins, and the loser's rows vanish with no error.
- Product creation inside the receive transaction can fail per-row on a SKU
  claim collision. Check whether a failed row aborts the whole receive, is
  skipped silently, or is reported. "Only some get successfully received"
  points at silent per-row failure.

**Do not fix by adding a cache first.** A caching layer over a last-write-wins
document hides the race rather than resolving it, and would make the loss
harder to see. Establish which of the three causes above is real, then decide:
per-row merge writes, an optimistic-concurrency guard (version field) on the
draft, or a transaction that fails loudly instead of partially.

**Reproduction to write first:** two clients open the same draft, each adds a
different row, both save. Then: two clients complete two different drafts that
both create new auto-SKU products at the same moment.

---

## 2. Closing day drops plate-number DP and delivery — money not reflected

> "she added everything already like the plate no dp, plate no delivery,
> expenses but only expenses reflected when the closing day is confirmed"

**Impact: the drawer reconciles against the wrong expected cash**, so a
correct count reads as a variance.

**CONFIRMED that the fields exist and are supposed to count.**
`lib/domain/entities/daily_closing_entity.dart` carries `plateNoDp` and
`plateNoDelivery` (fields at lines 198-199), and expected cash is:

```
openingFloat + cashSales - cashExpenses + plateNoDp - plateNoDelivery
```

So the model is right and the two amounts are meant to move the expected
total in opposite directions.

**HYPOTHESIS for the break:** the values are entered in the closing form but
are not carried into the entity that gets confirmed — either the form state is
not read at confirm time, or the write drops the two keys, or a default of `0`
overwrites them. Expenses surviving while these two do not suggests the
expense path is wired and these two were missed.

**Check both surfaces.** The cashier was on mobile; confirm whether the web
closing screen has the same gap.

---

## 3. Receiving preview shows the same SKU for every new product — CONFIRMED

> "when I create a new product via web admin receiving and have not saved as
> draft or confirmed the receiving yet, the initial list display do not
> reflect the real sku. all of them reflect the same sku."

**CONFIRMED, exact cause.** `web_admin/src/domain/receiving/receivableItem.ts`
(~line 68) gives every auto-SKU row the placeholder `composeAutoSku(code, 1)`
— **sequence 1, for every row**. The comment is explicit that this is a
placeholder the transaction later replaces by scanning the registry.

The placeholder is correct as a *seed*; the defect is that it is **shown to
the operator as if it were the SKU**. Two rows in the same category therefore
display an identical code before saving.

**Fix direction:** do not display a peeked sequence at all before allocation.
Show "will be assigned" (or the category code with the sequence blanked) until
the row has a real SKU, which it gets once the receive transaction runs. This
is the same family as the preview-SKU bug already fixed at write time in
`withAllocatedSku` — that fix corrected what was *stored*; this is what is
*shown*.

Low risk, high clarity: worth doing even before item 1.

---

## 4. Web admin has no void-request notification — CONFIRMED gap

> "web admin cannot receive void requests notif like in mobile admin"

**CONFIRMED as missing.** Mobile has an unread-count provider feeding a
notification badge (`lib/presentation/providers/void_request_provider.dart:65`,
*"Unread void-request count (notification badge)"*). The web admin has the
repository and a hook (`FirestoreVoidRequestRepository.ts`,
`useVoidRequest.ts`) but no equivalent badge or notification surface.

**Fix direction:** mirror the mobile unread count into the web sidebar. The
data layer already exists, so this is presentation only. Note that an admin
working only on web currently has no idea a cashier is waiting on a void.

---

## 5. Job order detail does not show the motorcycle model — CONFIRMED

> "job order in web admin, do not show the motorcycle model being worked on
> per job order details"

**CONFIRMED, and it is worse than a missing label.** Mobile's
`JobOrderEntity` carries `motorcycleModel` (`lib/domain/entities/job_order_entity.dart:45`).
The web admin has **zero references to `motorcycle` anywhere** in
`web_admin/src/domain` or `web_admin/src/presentation` — the field is not
mapped into the web JobOrder type at all, so it is not merely unrendered.

**Fix direction:** add the field to the web JobOrder type and its Firestore
mapper, then render it in `JobOrderEditPage`. Check the list page too — the
model is how staff recognise a bike at a glance.

---

## Suggested order

1. **#3** — confirmed, contained, removes a misleading display. Quick win.
2. **#5** and **#4** — confirmed, additive, no data risk.
3. **#2** — money correctness; needs a careful read of both closing forms.
4. **#1** — the dangerous one, and the only one needing real design work.
   Reproduce the race before choosing a fix; resist the cache-first instinct.
