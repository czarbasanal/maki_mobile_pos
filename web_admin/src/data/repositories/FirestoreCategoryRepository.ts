import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  runTransaction,
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
import { CategoryKind, collectionForKind } from '@/domain/categories/categoryKind';
import { categoryConverter } from '@/data/converters/categoryConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

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
    const data = {
      name,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    };

    if (kind !== CategoryKind.product) {
      const ref = await addDoc(collection(this.db, collectionForKind(kind)), data);
      const snap = await getDoc(ref.withConverter(categoryConverter));
      const created = snap.data();
      if (!created) throw new Error('Failed to load the created category');
      return created;
    }

    // Product categories additionally claim the next sequential Code128
    // category code, atomically with the category write. Mirrors
    // CategoryRepositoryImpl.createCategory(assignCode: true) on mobile —
    // doc shapes must stay byte-identical (shared registry/counter docs).
    const ref = doc(collection(this.db, collectionForKind(kind))); // pre-allocate id
    const counterRef = doc(this.db, FirestoreCollections.categoryCodes, '_counter');
    let assignedCode = '';

    await runTransaction(this.db, async (tx) => {
      const counterSnap = await tx.get(counterRef);
      const next = (counterSnap.data()?.next as number | undefined) ?? 1;
      assignedCode = next.toString().padStart(4, '0');
      const registryRef = doc(this.db, FirestoreCollections.categoryCodes, assignedCode);

      tx.set(ref, { ...data, code: assignedCode });
      tx.set(registryRef, {
        categoryId: ref.id,
        nameSnapshot: name,
        assignedAt: serverTimestamp(),
        nextSequence: 1,
      });
      tx.set(counterRef, { next: next + 1 });
    });

    const snap = await getDoc(ref.withConverter(categoryConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created category');
    return created;
  }

  async peekNextSequence(categoryCode: string): Promise<number> {
    const snap = await getDoc(doc(this.db, FirestoreCollections.categoryCodes, categoryCode));
    if (!snap.exists()) {
      throw new Error(`Unknown category code "${categoryCode}"`);
    }
    return (snap.data()?.nextSequence as number | undefined) ?? 1;
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
