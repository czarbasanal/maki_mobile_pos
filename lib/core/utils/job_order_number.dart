/// Daily-sequential Job Order numbers: `JO-MMDDYY-NNN`.
///
/// The date is embedded in the prefix, so "today's sequence" is derived
/// purely from names carrying today's prefix — legacy customer/plate names
/// and other days' numbers never collide. Sequence gaps (deleted tickets)
/// are not reused: the next number is max(today) + 1 as of the read.
///
/// DELIBERATE TRADE-OFF: the read-then-write is not transactional, so two
/// devices saving within the same read/write window can mint the same
/// number. Accepted for this label (small shop, 1-2 registers) — if JO
/// numbers ever become load-bearing references, move to a claim doc like
/// the SKU/barcode guards.
library;

/// `JO-MMDDYY-` for [now]'s date, e.g. `JO-072326-` on 2026-07-23.
String jobOrderPrefixFor(DateTime now) {
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  final yy = (now.year % 100).toString().padLeft(2, '0');
  return 'JO-$mm$dd$yy-';
}

/// The next job-order number for [now]'s date, given the [existingNames]
/// of drafts created today (converted ones included, so billed-out numbers
/// are never reissued). Zero-padded to 3 digits, growing naturally past 999.
String nextJobOrderNumber(DateTime now, Iterable<String> existingNames) {
  final prefix = jobOrderPrefixFor(now);
  var maxSeq = 0;
  for (final name in existingNames) {
    if (!name.startsWith(prefix)) continue;
    final seq = int.tryParse(name.substring(prefix.length));
    if (seq != null && seq > maxSeq) maxSeq = seq;
  }
  return '$prefix${(maxSeq + 1).toString().padLeft(3, '0')}';
}
