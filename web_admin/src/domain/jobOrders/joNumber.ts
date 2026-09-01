import { shopTimeOf } from '@/domain/time/shopTime';
// Port of lib/core/utils/job_order_number.dart. Daily-sequential Job Order
// numbers: `JO-MMDDYY-NNN`. The date is embedded in the prefix, so "today's
// sequence" is derived purely from names carrying today's prefix — legacy
// customer/plate names and other days' numbers never collide. Sequence gaps
// (deleted tickets) are not reused: the next number is max(today) + 1 as of
// the read.
//
// DELIBERATE TRADE-OFF (mirrors the Dart original): the read-then-write is
// not transactional, so two tabs/devices saving within the same read/write
// window can mint the same number. Accepted for this label (small shop,
// 1-2 registers) — if JO numbers ever become load-bearing references, move
// to a claim doc like the SKU/barcode guards.
//
// Keep this file and lib/core/utils/job_order_number.dart byte-identical in
// behavior (prefix format, padding widths, ignore rules for malformed/other-
// day names).

/** `JO-MMDDYY-` for `now`'s date, e.g. `JO-072326-` on 2026-07-23. */
export function jobOrderPrefixFor(now: Date): string {
  // SHOP (PHT) calendar date — a foreign-timezone device must mint the
  // same day prefix as the register.
  const wall = shopTimeOf(now);
  const mm = String(wall.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(wall.getUTCDate()).padStart(2, '0');
  const yy = String(wall.getUTCFullYear() % 100).padStart(2, '0');
  return `JO-${mm}${dd}${yy}-`;
}

/**
 * The next job-order number for `now`'s date, given the `existingNames` of
 * job orders created today (converted ones included, so billed-out numbers are
 * never reissued). Zero-padded to 3 digits, growing naturally past 999.
 */
export function nextJobOrderNumber(now: Date, existingNames: Iterable<string>): string {
  const prefix = jobOrderPrefixFor(now);
  let maxSeq = 0;
  for (const name of existingNames) {
    if (!name.startsWith(prefix)) continue;
    const suffix = name.slice(prefix.length);
    // Dart's int.tryParse rejects anything that isn't a whole valid integer
    // (incl. empty and non-digit suffixes) — mirror that with a strict regex
    // rather than JS's lenient Number()/parseInt() coercion.
    if (!/^\d+$/.test(suffix)) continue;
    const seq = Number(suffix);
    if (seq > maxSeq) maxSeq = seq;
  }
  return `${prefix}${String(maxSeq + 1).padStart(3, '0')}`;
}
