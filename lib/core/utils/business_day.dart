/// Business-day boundary helpers.
///
/// The shop runs on Philippine local time, which has no DST — so "the next
/// business day" is always plain next 00:00 local time, no offset math.
/// These helpers are pure (take the reference [DateTime] explicitly) so
/// they're trivially unit-testable without a clock abstraction.
library;

/// Next local midnight strictly after [t] (PH has no DST — plain next 00:00).
DateTime nextMidnightAfter(DateTime t) => DateTime(t.year, t.month, t.day + 1);

/// Midnight-truncated date for [t].
DateTime businessDateOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// yyyymmdd int for the drawer_state doc / rules comparisons.
int businessDayInt(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

/// Inverse of [businessDayInt] — parses a yyyymmdd int back into a
/// midnight-truncated [DateTime].
DateTime dateFromBusinessDayInt(int yyyymmdd) => DateTime(
      yyyymmdd ~/ 10000,
      (yyyymmdd ~/ 100) % 100,
      yyyymmdd % 100,
    );
