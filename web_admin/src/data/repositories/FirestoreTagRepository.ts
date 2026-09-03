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
  type Firestore,
} from 'firebase/firestore';
import type {
  TagCreateInput,
  TagRepository,
  TagUpdateInput,
} from '@/domain/repositories/TagRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Tag } from '@/domain/entities';
import { tagConverter } from '@/data/converters/tagConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `product_tags` is a small collection — read the whole list and filter/sort
// client-side (no composite index), mirroring FirestoreMechanicRepository.
export class FirestoreTagRepository implements TagRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.productTags).withConverter(tagConverter);
  }

  private shape(items: Tag[], includeInactive: boolean): Tag[] {
    const out = includeInactive ? items : items.filter((t) => t.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  watchAll(cb: (tags: Tag[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe {
    return onSnapshot(this.col(), (snap) => {
      cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
    });
  }

  async nameExists(name: string): Promise<boolean> {
    const snap = await getDocs(
      query(collection(this.db, FirestoreCollections.productTags), where('name', '==', name), limit(1)),
    );
    return !snap.empty;
  }

  async create(input: TagCreateInput, actorId: string): Promise<Tag> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.productTags), {
      name: input.name,
      color: input.color,
      description: input.description ?? null,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(tagConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created tag');
    return created;
  }

  async update(id: string, input: TagUpdateInput, actorId: string): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.color !== undefined) data.color = input.color;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    if (input.description !== undefined) data.description = input.description;
    await updateDoc(doc(this.db, FirestoreCollections.productTags, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.productTags, id));
  }
}
