import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  query,
  where,
  serverTimestamp,
  updateDoc,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import type {
  AdjustmentReasonCreateInput,
  AdjustmentReasonRepository,
  AdjustmentReasonUpdateInput,
} from '@/domain/repositories/AdjustmentReasonRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { AdjustmentReason } from '@/domain/entities';
import { adjustmentReasonConverter } from '@/data/converters/adjustmentReasonConverter';
import { SEED_REASONS } from '@/domain/adjustments/seedReasons';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `adjustment_reasons` is a small collection — read the whole list and filter/sort
// client-side (no composite index), mirroring FirestoreTagRepository.
export class FirestoreAdjustmentReasonRepository implements AdjustmentReasonRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.adjustmentReasons).withConverter(adjustmentReasonConverter);
  }

  private shape(items: AdjustmentReason[], includeInactive: boolean): AdjustmentReason[] {
    const out = includeInactive ? items : items.filter((r) => r.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  watchAll(cb: (reasons: AdjustmentReason[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe {
    return onSnapshot(this.col(), (snap) => {
      cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
    });
  }

  async nameExists(name: string): Promise<boolean> {
    const snap = await getDocs(
      query(collection(this.db, FirestoreCollections.adjustmentReasons), where('name', '==', name), limit(1)),
    );
    return !snap.empty;
  }

  async create(input: AdjustmentReasonCreateInput, actorId: string): Promise<AdjustmentReason> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.adjustmentReasons), {
      name: input.name,
      requiresNote: input.requiresNote ?? false,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(adjustmentReasonConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created adjustment reason');
    return created;
  }

  async update(id: string, input: AdjustmentReasonUpdateInput, actorId: string): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.requiresNote !== undefined) data.requiresNote = input.requiresNote;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    await updateDoc(doc(this.db, FirestoreCollections.adjustmentReasons, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.adjustmentReasons, id));
  }

  async seedDefaults(actorId: string): Promise<void> {
    const batch = writeBatch(this.db);
    for (const seed of SEED_REASONS) {
      batch.set(doc(collection(this.db, FirestoreCollections.adjustmentReasons)), {
        name: seed.name,
        requiresNote: seed.requiresNote,
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        createdBy: actorId,
        updatedBy: actorId,
      });
    }
    await batch.commit();
  }
}
