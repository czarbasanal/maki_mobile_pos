import type { ShopTimezone } from '@/domain/time/shopTime';

/** The timezone keys of the shared settings/general doc. */
export interface ShopTimezoneRepository {
  /** Subscribes to changes; returns the unsubscribe function. */
  watch(onChange: (tz: ShopTimezone) => void): () => void;
  get(): Promise<ShopTimezone>;
  save(tz: ShopTimezone, updatedBy: string): Promise<void>;
}
