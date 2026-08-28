// Optimistic concurrency for receiving drafts.
//
// A draft's `items` is written as a whole array from one client's in-memory
// list. Two clients editing the same draft therefore used to overwrite each
// other silently — the loser's rows simply vanished, with no error and no way
// to notice until the stock did not add up. This turns that into a refusal.
//
// The version lives on the doc and is bumped by every web write. Documents
// written before this existed — and any written by the mobile app, which does
// not bump it — read as version 0, so a mobile edit interleaved with a web one
// is still not detected. Web-to-web, which is what was reported (a tablet and
// a laptop receiving at the same time), is.

export const RECEIVING_CONFLICT_MESSAGE =
  'This receiving was changed on another device. Reload the page to see the ' +
  'current items, then re-apply your changes.';

/** Reads a doc's version, treating a missing/invalid field as 0. */
export function receivingVersion(raw: unknown): number {
  return typeof raw === 'number' && Number.isFinite(raw) && raw >= 0 ? raw : 0;
}

/** True when the doc moved on since the client read it. */
export function isReceivingConflict(expected: number, current: number): boolean {
  return receivingVersion(expected) !== receivingVersion(current);
}

/** The version to stamp on the write that follows a passing check. */
export function nextReceivingVersion(current: number): number {
  return receivingVersion(current) + 1;
}
