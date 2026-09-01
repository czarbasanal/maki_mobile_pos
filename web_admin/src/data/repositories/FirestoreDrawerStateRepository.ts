import { doc, onSnapshot, type Firestore } from 'firebase/firestore';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import type { DrawerState } from '@/domain/entities/DrawerState';
import type { DrawerStateRepository } from '@/domain/repositories/DrawerStateRepository';

export class FirestoreDrawerStateRepository implements DrawerStateRepository {
  constructor(private readonly db: Firestore) {}

  watch(onChange: (state: DrawerState) => void, onError?: (error: Error) => void): () => void {
    const ref = doc(this.db, FirestoreCollections.drawerState, 'state');
    return onSnapshot(
      ref,
      (snapshot) => {
        const data = snapshot.data();
        onChange({
          lastSaleDay: typeof data?.lastSaleDay === 'number' ? data.lastSaleDay : null,
          lastClosedDay: typeof data?.lastClosedDay === 'number' ? data.lastClosedDay : null,
        });
      },
      (error) => onError?.(error),
    );
  }
}
