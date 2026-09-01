import {
  addDoc,
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import {
  canonicalModelName,
  normalizedModelKey,
  type MotorcycleModel,
} from '@/domain/entities/MotorcycleModel';
import type { MotorcycleModelRepository } from '@/domain/repositories/MotorcycleModelRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

function parseModel(id: string, data: Record<string, unknown> | undefined): MotorcycleModel {
  return {
    id,
    name: typeof data?.name === 'string' ? data.name : '',
    isActive: data?.isActive !== false,
  };
}

export class FirestoreMotorcycleModelRepository implements MotorcycleModelRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.motorcycleModels);
  }

  watchActive(onData: (models: MotorcycleModel[]) => void, onError?: (e: Error) => void): Unsubscribe {
    // No orderBy — mirrors mobile; a server orderBy would need a composite
    // index that doesn't exist. Sorted client-side.
    return onSnapshot(
      query(this.col(), where('isActive', '==', true)),
      (snap) =>
        onData(
          snap.docs
            .map((d) => parseModel(d.id, d.data()))
            .sort((a, b) => a.name.localeCompare(b.name)),
        ),
      (e) => onError?.(e),
    );
  }

  async findByNormalizedKey(key: string): Promise<MotorcycleModel | null> {
    const snap = await getDocs(query(this.col(), where('normalizedName', '==', key), limit(1)));
    if (snap.empty) return null;
    const d = snap.docs[0];
    return parseModel(d.id, d.data());
  }

  async create(name: string, actorId: string): Promise<MotorcycleModel> {
    const canonical = canonicalModelName(name);
    const ref = await addDoc(this.col(), {
      name: canonical,
      normalizedName: normalizedModelKey(name),
      isActive: true,
      createdAt: serverTimestamp(),
      createdBy: actorId,
    });
    return { id: ref.id, name: canonical, isActive: true };
  }

  async setActive(id: string, active: boolean, actorId: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.motorcycleModels, id), {
      isActive: active,
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
    });
  }
}
