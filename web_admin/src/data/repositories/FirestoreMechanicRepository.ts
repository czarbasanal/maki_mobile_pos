import {
  addDoc,
  collection,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type {
  MechanicRepository,
  MechanicUpdateInput,
} from '@/domain/repositories/MechanicRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Mechanic } from '@/domain/entities';
import { mechanicConverter } from '@/data/converters/mechanicConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `mechanics` is a small collection — read the whole list and filter/sort
// client-side (no composite index), mirroring FirestoreCategoryRepository.
export class FirestoreMechanicRepository implements MechanicRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.mechanics).withConverter(mechanicConverter);
  }

  private shape(items: Mechanic[], includeInactive: boolean): Mechanic[] {
    const out = includeInactive ? items : items.filter((m) => m.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  watchAll(cb: (mechanics: Mechanic[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe {
    return onSnapshot(this.col(), (snap) => {
      cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
    });
  }

  async create(name: string, actorId: string): Promise<Mechanic> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.mechanics), {
      name,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(mechanicConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created mechanic');
    return created;
  }

  async update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    await updateDoc(doc(this.db, FirestoreCollections.mechanics, id), data);
  }
}
