import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type { DraftRepository } from '@/domain/repositories/DraftRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Draft } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { draftConverter, draftItemsToMaps } from '@/data/converters/draftConverter';
import { laborLinesToMaps } from '@/data/converters/laborLines';

export class FirestoreDraftRepository implements DraftRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.drafts).withConverter(draftConverter);
  }

  async getById(id: string): Promise<Draft | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.drafts, id).withConverter(draftConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  watchAll(callback: (drafts: Draft[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), orderBy('createdAt', 'desc')), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  async create(draft: Omit<Draft, 'id' | 'createdAt' | 'updatedAt'>): Promise<Draft> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.drafts), {
      name: draft.name,
      items: draftItemsToMaps(draft.items),
      laborLines: laborLinesToMaps(draft.laborLines),
      mechanicId: draft.mechanicId ?? null,
      mechanicName: draft.mechanicName ?? null,
      discountType: draft.discountType,
      createdBy: draft.createdBy,
      createdByName: draft.createdByName,
      updatedBy: draft.updatedBy ?? null,
      isConverted: draft.isConverted ?? false,
      convertedToSaleId: draft.convertedToSaleId ?? null,
      convertedAt: draft.convertedAt ?? null,
      notes: draft.notes ?? null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created draft');
    return created;
  }

  async update(
    id: string,
    patch: Partial<Omit<Draft, 'id' | 'createdAt'>>,
    actorId: string,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (patch.name !== undefined) data.name = patch.name;
    if (patch.items !== undefined) data.items = draftItemsToMaps(patch.items);
    if (patch.laborLines !== undefined) data.laborLines = laborLinesToMaps(patch.laborLines);
    if (patch.mechanicId !== undefined) data.mechanicId = patch.mechanicId;
    if (patch.mechanicName !== undefined) data.mechanicName = patch.mechanicName;
    if (patch.discountType !== undefined) data.discountType = patch.discountType;
    if (patch.notes !== undefined) data.notes = patch.notes;
    await updateDoc(doc(this.db, FirestoreCollections.drafts, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.drafts, id));
  }

}
