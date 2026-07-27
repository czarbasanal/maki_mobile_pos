// Pure decision logic for the drafts → job_orders schema migration.
// The runner (migrate-drafts-to-job-orders.mjs) maps DELETE_FIELD to
// FieldValue.delete(); tests exercise these functions directly.

export const DELETE_FIELD = Symbol('DELETE_FIELD');

/** Best-effort millis from a Firestore Timestamp / Date / number / null. */
export function tsMillis(v) {
  if (v == null) return null;
  if (typeof v === 'number') return v;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return null;
}

/**
 * Should drafts/{id} be copied over job_orders/{id}?
 * Idempotent + re-run safe:
 * - missing target → copy;
 * - a converted target is never clobbered by an unconverted source (a re-run
 *   must not un-bill a ticket that was billed out post-cutover);
 * - otherwise copy only when the source is strictly newer
 *   (updatedAt ?? createdAt) — post-cutover edits in job_orders win.
 *
 * @returns {{ copy: boolean, reason: string }}
 */
export function shouldCopy(source, target) {
  if (!target) return { copy: true, reason: 'target-missing' };
  const srcConverted = source.isConverted === true;
  const tgtConverted = target.isConverted === true;
  if (tgtConverted && !srcConverted) {
    return { copy: false, reason: 'target-converted' };
  }
  const srcT = tsMillis(source.updatedAt) ?? tsMillis(source.createdAt) ?? 0;
  const tgtT = tsMillis(target.updatedAt) ?? tsMillis(target.createdAt) ?? 0;
  if (srcT > tgtT) return { copy: true, reason: 'source-newer' };
  return { copy: false, reason: 'target-not-older' };
}

/**
 * Plan the sales-doc field move draftId → jobOrderId.
 * - draftId only            → set jobOrderId, delete draftId
 * - both (already migrated + old field lingering) → delete draftId only
 * - jobOrderId only / neither → null (no patch)
 */
export function planSalePatch(sale) {
  const hasOld = sale.draftId !== undefined && sale.draftId !== null;
  const hasNew = sale.jobOrderId !== undefined && sale.jobOrderId !== null;
  if (!hasOld) return null;
  if (hasNew) return { draftId: DELETE_FIELD };
  return { jobOrderId: sale.draftId, draftId: DELETE_FIELD };
}
