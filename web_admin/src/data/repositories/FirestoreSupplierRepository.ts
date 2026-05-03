// Firestore implementation of SupplierRepository. Mirrors
// lib/data/repositories/supplier_repository_impl.dart with the same name
// uniqueness check and writeable searchKeywords array.

import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  limit as fsLimit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import type { SupplierRepository } from '@/domain/repositories/SupplierRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Supplier } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { supplierConverter } from '@/data/converters/supplierConverter';
import { supplierSearchKeywords } from '@/core/utils/searchKeywords';

type SupplierCreateInput = Omit<
  Supplier,
  'id' | 'createdAt' | 'updatedAt' | 'productCount' | 'totalInventoryValue'
>;

export class FirestoreSupplierRepository implements SupplierRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.suppliers).withConverter(
      supplierConverter,
    );
  }

  async getById(id: string): Promise<Supplier | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.suppliers, id).withConverter(supplierConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  async list(): Promise<Supplier[]> {
    const snap = await getDocs(query(this.col(), orderBy('name')));
    return snap.docs.map((d) => d.data());
  }

  watchAll(callback: (suppliers: Supplier[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), orderBy('name')), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  async nameExists(name: string, excludeId?: string): Promise<boolean> {
    const snap = await getDocs(
      query(this.col(), where('name', '==', name.trim()), fsLimit(2)),
    );
    return snap.docs.some((d) => d.id !== excludeId);
  }

  async create(input: SupplierCreateInput, actorId: string): Promise<Supplier> {
    if (await this.nameExists(input.name)) {
      throw new Error('A supplier with this name already exists');
    }
    const col = collection(this.db, FirestoreCollections.suppliers);
    const ref = await addDoc(col, {
      name: input.name.trim(),
      address: input.address ?? null,
      contactPerson: input.contactPerson ?? null,
      contactNumber: input.contactNumber ?? null,
      alternativeNumber: input.alternativeNumber ?? null,
      email: input.email ?? null,
      transactionType: input.transactionType,
      isActive: true,
      notes: input.notes ?? null,
      productCount: 0,
      totalInventoryValue: 0,
      searchKeywords: supplierSearchKeywords(
        input.name,
        input.contactPerson,
        input.address,
      ),
      createdBy: actorId,
      updatedBy: actorId,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load created supplier');
    return created;
  }

  async update(
    id: string,
    input: Partial<Omit<Supplier, 'id' | 'createdAt'>>,
    actorId: string,
  ): Promise<void> {
    if (input.name !== undefined && (await this.nameExists(input.name, id))) {
      throw new Error('A supplier with this name already exists');
    }

    const patch: Record<string, unknown> = {
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
    };
    type Updatable =
      | 'name'
      | 'address'
      | 'contactPerson'
      | 'contactNumber'
      | 'alternativeNumber'
      | 'email'
      | 'transactionType'
      | 'isActive'
      | 'notes';
    const fields: Updatable[] = [
      'name',
      'address',
      'contactPerson',
      'contactNumber',
      'alternativeNumber',
      'email',
      'transactionType',
      'isActive',
      'notes',
    ];
    for (const f of fields) {
      const v = input[f];
      if (v !== undefined) patch[f] = v ?? null;
    }
    if (typeof patch.name === 'string') patch.name = (patch.name as string).trim();

    // Re-generate searchKeywords if any of its inputs may have changed.
    if (
      input.name !== undefined ||
      input.contactPerson !== undefined ||
      input.address !== undefined
    ) {
      const current = await this.getById(id);
      patch.searchKeywords = supplierSearchKeywords(
        (input.name ?? current?.name) ?? '',
        input.contactPerson ?? current?.contactPerson,
        input.address ?? current?.address,
      );
    }

    await updateDoc(doc(this.db, FirestoreCollections.suppliers, id), patch);
  }

  async deactivate(id: string, actorId: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.suppliers, id), {
      isActive: false,
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
    });
  }
}
