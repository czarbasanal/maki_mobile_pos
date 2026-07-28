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
import type { JobOrderRepository } from '@/domain/repositories/JobOrderRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { JobOrder } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { jobOrderConverter, jobOrderItemsToMaps } from '@/data/converters/jobOrderConverter';
import { laborLinesToMaps } from '@/data/converters/laborLines';
import { feeLinesToMaps } from '@/data/converters/feeLines';

export class FirestoreJobOrderRepository implements JobOrderRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.jobOrders).withConverter(jobOrderConverter);
  }

  async getById(id: string): Promise<JobOrder | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.jobOrders, id).withConverter(jobOrderConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  watchAll(callback: (jobOrders: JobOrder[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), orderBy('createdAt', 'desc')), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  async create(jobOrder: Omit<JobOrder, 'id' | 'createdAt' | 'updatedAt'>): Promise<JobOrder> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.jobOrders), {
      name: jobOrder.name,
      items: jobOrderItemsToMaps(jobOrder.items),
      laborLines: laborLinesToMaps(jobOrder.laborLines),
      feeLines: feeLinesToMaps(jobOrder.feeLines),
      mechanicId: jobOrder.mechanicId ?? null,
      mechanicName: jobOrder.mechanicName ?? null,
      discountType: jobOrder.discountType,
      createdBy: jobOrder.createdBy,
      createdByName: jobOrder.createdByName,
      updatedBy: jobOrder.updatedBy ?? null,
      isConverted: jobOrder.isConverted ?? false,
      convertedToSaleId: jobOrder.convertedToSaleId ?? null,
      convertedAt: jobOrder.convertedAt ?? null,
      notes: jobOrder.notes ?? null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created Job Order');
    return created;
  }

  async update(
    id: string,
    patch: Partial<Omit<JobOrder, 'id' | 'createdAt'>>,
    actorId: string,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (patch.name !== undefined) data.name = patch.name;
    if (patch.items !== undefined) data.items = jobOrderItemsToMaps(patch.items);
    if (patch.laborLines !== undefined) data.laborLines = laborLinesToMaps(patch.laborLines);
    if (patch.feeLines !== undefined) data.feeLines = feeLinesToMaps(patch.feeLines);
    if (patch.mechanicId !== undefined) data.mechanicId = patch.mechanicId;
    if (patch.mechanicName !== undefined) data.mechanicName = patch.mechanicName;
    if (patch.discountType !== undefined) data.discountType = patch.discountType;
    if (patch.notes !== undefined) data.notes = patch.notes;
    await updateDoc(doc(this.db, FirestoreCollections.jobOrders, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.jobOrders, id));
  }

}
