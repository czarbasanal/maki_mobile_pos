export type DraftConversionOutcome = 'convert' | 'skip' | 'abort';

/** What a sale's transaction should do with its source draft.
 *  - missing draft (deleted mid-checkout) → skip; the sale still commits.
 *  - already converted → abort; the whole sale rolls back (no duplicate sale).
 *  - present & not converted → convert it atomically with the sale. */
export function draftConversionOutcome(
  exists: boolean,
  isConverted: boolean,
): DraftConversionOutcome {
  if (!exists) return 'skip';
  if (isConverted) return 'abort';
  return 'convert';
}
