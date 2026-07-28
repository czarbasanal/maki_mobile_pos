// Safety predicate for deleting the legacy `drafts` documents left behind as
// a backup by the drafts→job_orders migration (2026-07-28).
//
// A draft may only be deleted when its `job_orders/{sameId}` counterpart
// exists AND still carries the same identifying content. Anything unexpected
// is reported, never deleted.

/** Fields that must match exactly between the legacy doc and its copy. */
const IDENTITY_FIELDS = ['name', 'createdBy', 'isConverted', 'convertedToSaleId'];

/**
 * @returns {{safe: boolean, reason: string}}
 */
export function safeToDelete(draft, jobOrder) {
  if (!jobOrder) return { safe: false, reason: 'no job_orders counterpart' };

  for (const f of IDENTITY_FIELDS) {
    const a = draft[f] ?? null;
    const b = jobOrder[f] ?? null;
    if (a !== b) {
      return { safe: false, reason: `${f} differs (${JSON.stringify(a)} vs ${JSON.stringify(b)})` };
    }
  }

  const aItems = Array.isArray(draft.items) ? draft.items.length : 0;
  const bItems = Array.isArray(jobOrder.items) ? jobOrder.items.length : 0;
  if (aItems !== bItems) {
    return { safe: false, reason: `item count differs (${aItems} vs ${bItems})` };
  }

  return { safe: true, reason: 'verified copy' };
}
