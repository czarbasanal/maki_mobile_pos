/// Canonical display form for a motorcycle model name: trimmed, internal
/// whitespace collapsed to single spaces, original case preserved.
String canonicalModelName(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Case-insensitive dedup key. "  nmax " and "Nmax" produce the same key, so
/// pick-or-add reuses one canonical row instead of forking frequency counts.
String normalizedModelKey(String raw) => canonicalModelName(raw).toLowerCase();
