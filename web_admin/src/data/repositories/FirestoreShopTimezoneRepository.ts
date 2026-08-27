// Firestore implementation over settings/general — the doc shared with the
// mobile app. Saves MERGE rather than overwrite: general is a bucket for
// other future settings, unlike settings/hr which is a full overwrite.

import {
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  setDoc,
  type Firestore,
} from 'firebase/firestore';
import type { ShopTimezoneRepository } from '@/domain/repositories/ShopTimezoneRepository';
import {
  DEFAULT_SHOP_OFFSET_MINUTES,
  DEFAULT_SHOP_TIMEZONE_ID,
  type ShopTimezone,
} from '@/domain/time/shopTime';
import { FirestoreCollections, SettingsDocs } from '@/infrastructure/firebase/collections';

const MIN_OFFSET = -720;
const MAX_OFFSET = 840;

/**
 * Defensive read: a missing doc, a missing key, a non-integer value, or an
 * out-of-range offset all fall back to the default. A bad value here would
 * break the business day on every browser, so the safest value wins.
 */
export function parseShopTimezone(data: Record<string, unknown> | undefined): ShopTimezone {
  const rawOffset = data?.tzOffsetMinutes;
  const rawId = data?.timezoneId;

  const offsetMinutes =
    typeof rawOffset === 'number' &&
    Number.isInteger(rawOffset) &&
    rawOffset >= MIN_OFFSET &&
    rawOffset <= MAX_OFFSET
      ? rawOffset
      : DEFAULT_SHOP_OFFSET_MINUTES;

  const timezoneId =
    typeof rawId === 'string' && rawId.length > 0 ? rawId : DEFAULT_SHOP_TIMEZONE_ID;

  return { timezoneId, offsetMinutes };
}

export class FirestoreShopTimezoneRepository implements ShopTimezoneRepository {
  constructor(private readonly db: Firestore) {}

  private docRef() {
    return doc(this.db, FirestoreCollections.settings, SettingsDocs.general);
  }

  watch(onChange: (tz: ShopTimezone) => void): () => void {
    return onSnapshot(this.docRef(), (snap) => {
      onChange(parseShopTimezone(snap.data() as Record<string, unknown> | undefined));
    });
  }

  async get(): Promise<ShopTimezone> {
    const snap = await getDoc(this.docRef());
    return parseShopTimezone(snap.data() as Record<string, unknown> | undefined);
  }

  async save(tz: ShopTimezone, updatedBy: string): Promise<void> {
    await setDoc(
      this.docRef(),
      {
        timezoneId: tz.timezoneId,
        tzOffsetMinutes: tz.offsetMinutes,
        updatedAt: serverTimestamp(),
        updatedBy,
      },
      { merge: true },
    );
  }
}
