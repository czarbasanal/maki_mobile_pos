import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '@/infrastructure/firebase/firestore';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import type { DrawerState } from '@/domain/entities/DrawerState';
import type { DrawerStateRepository } from '@/domain/repositories/DrawerStateRepository';

export class FirestoreDrawerStateRepository implements DrawerStateRepository {
  watch(onChange: (state: DrawerState) => void, onError?: (error: Error) => void): () => void {
    const ref = doc(db, FirestoreCollections.drawerState, 'state');
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
