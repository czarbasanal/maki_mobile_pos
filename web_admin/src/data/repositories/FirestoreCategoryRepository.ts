import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type {
  CategoryRepository,
  CategoryUpdateInput,
} from '@/domain/repositories/CategoryRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Category } from '@/domain/entities';
import type { CategoryKind } from '@/domain/categories/categoryKind';
import { collectionForKind } from '@/domain/categories/categoryKind';
import { categoryConverter } from '@/data/converters/categoryConverter';

// Categories are small collections, so we read the whole list and filter/sort
// client-side — no composite index required.
export class FirestoreCategoryRepository implements CategoryRepository {
  constructor(private readonly db: Firestore) {}

  private col(kind: CategoryKind) {
    return collection(this.db, collectionForKind(kind)).withConverter(categoryConverter);
  }

  private shape(cats: Category[], includeInactive: boolean): Category[] {
    const out = includeInactive ? cats : cats.filter((c) => c.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  async list(kind: CategoryKind, opts?: { includeInactive?: boolean }): Promise<Category[]> {
    const snap = await getDocs(this.col(kind));
    return this.shape(
      snap.docs.map((d) => d.data()),
      opts?.includeInactive ?? false,
    );
  }

  watchAll(
    kind: CategoryKind,
    cb: (categories: Category[]) => void,
    opts?: { includeInactive?: boolean },
  ): Unsubscribe {
    return onSnapshot(this.col(kind), (snap) => {
      cb(
        this.shape(
          snap.docs.map((d) => d.data()),
          opts?.includeInactive ?? false,
        ),
      );
    });
  }

  async create(kind: CategoryKind, name: string, actorId: string): Promise<Category> {
    const ref = await addDoc(collection(this.db, collectionForKind(kind)), {
      name,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(categoryConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created category');
    return created;
  }

  async update(
    kind: CategoryKind,
    id: string,
    input: CategoryUpdateInput,
    actorId: string,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    await updateDoc(doc(this.db, collectionForKind(kind), id), data);
  }
}
