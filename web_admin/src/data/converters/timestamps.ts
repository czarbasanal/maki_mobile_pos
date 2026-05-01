// Helpers for parsing Firestore Timestamps in user-tolerant ways. Mirror the
// behaviour of `_parseTimestamp` in lib/data/models/sale_model.dart: accept
// Firestore Timestamp objects (`{ seconds, nanoseconds }`), Date instances,
// or ISO strings — any of which can land in a snapshot when documents are
// written from different clients.

import { Timestamp } from 'firebase/firestore';

export function toDate(value: unknown): Date | null {
  if (value == null) return null;
  if (value instanceof Date) return value;
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof value === 'object' && 'seconds' in (value as Record<string, unknown>)) {
    const seconds = (value as { seconds: number }).seconds;
    const nanoseconds = (value as { nanoseconds?: number }).nanoseconds ?? 0;
    return new Date(seconds * 1000 + nanoseconds / 1e6);
  }
  return null;
}

export function requireDate(value: unknown, field: string): Date {
  const d = toDate(value);
  if (!d) throw new Error(`Missing required date field: ${field}`);
  return d;
}
