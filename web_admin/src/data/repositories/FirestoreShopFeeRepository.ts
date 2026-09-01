import { collection, onSnapshot, query, where, type Firestore } from 'firebase/firestore';
import type { ShopFee } from '@/domain/entities/ShopFee';
import type { ShopFeeRepository } from '@/domain/repositories/ShopFeeRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

export function parseShopFee(id: string, data: Record<string, unknown> | undefined): ShopFee {
  return {
    id,
    name: typeof data?.name === 'string' ? data.name : '',
    defaultAmount: typeof data?.defaultAmount === 'number' ? data.defaultAmount : null,
    isActive: data?.isActive !== false,
  };
}

export class FirestoreShopFeeRepository implements ShopFeeRepository {
  constructor(private readonly db: Firestore) {}

  watchActive(onData: (fees: ShopFee[]) => void, onError?: (e: Error) => void): Unsubscribe {
    // No orderBy: mirrors mobile's watchActive — a server-side orderBy here
    // would demand a composite index that doesn't exist. Sort client-side.
    const q = query(
      collection(this.db, FirestoreCollections.shopFees),
      where('isActive', '==', true),
    );
    return onSnapshot(
      q,
      (snap) =>
        onData(
          snap.docs
            .map((d) => parseShopFee(d.id, d.data()))
            .sort((a, b) => a.name.localeCompare(b.name)),
        ),
      (e) => onError?.(e),
    );
  }
}
