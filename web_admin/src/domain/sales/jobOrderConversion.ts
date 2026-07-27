export type JobOrderConversionOutcome = 'convert' | 'skip' | 'abort';

/** What a sale's transaction should do with its source job order.
 *  - missing job order (deleted mid-checkout) → skip; the sale still commits.
 *  - already converted → abort; the whole sale rolls back (no duplicate sale).
 *  - present & not converted → convert it atomically with the sale. */
export function jobOrderConversionOutcome(
  exists: boolean,
  isConverted: boolean,
): JobOrderConversionOutcome {
  if (!exists) return 'skip';
  if (isConverted) return 'abort';
  return 'convert';
}
