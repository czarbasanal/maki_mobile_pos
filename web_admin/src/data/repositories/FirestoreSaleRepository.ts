// Read-side implementation of SaleRepository. Phase 2 only needs watchToday
// (dashboard) — write paths land alongside the POS migration in phase 11.

import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit as fbLimit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  where,
  type Firestore,
} from 'firebase/firestore';
import type {
  SaleListFilters,
  SaleRepository,
} from '@/domain/repositories/SaleRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Sale } from '@/domain/entities';
import { FirestoreCollections, Subcollections } from '@/infrastructure/firebase/collections';
import { saleConverter } from '@/data/converters/saleConverter';
import { saleItemConverter } from '@/data/converters/saleItemConverter';
import { counterKey, formatSaleNumber } from '@/domain/sales/saleNumber';

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
}

function endOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
}

export class FirestoreSaleRepository implements SaleRepository {
  constructor(private readonly db: Firestore) {}

  private salesCol() {
    return collection(this.db, FirestoreCollections.sales).withConverter(saleConverter);
  }

  private itemsCol(saleId: string) {
    return collection(
      this.db,
      FirestoreCollections.sales,
      saleId,
      Subcollections.saleItems,
    ).withConverter(saleItemConverter);
  }

  async getById(id: string): Promise<Sale | null> {
    const ref = doc(this.db, FirestoreCollections.sales, id).withConverter(saleConverter);
    const snap = await getDoc(ref);
    if (!snap.exists()) return null;
    const sale = snap.data();
    sale.items = await this.loadItems(id);
    return sale;
  }

  async list(filters: SaleListFilters = {}): Promise<Sale[]> {
    const constraints = [];
    if (filters.start) {
      constraints.push(where('createdAt', '>=', Timestamp.fromDate(filters.start)));
    }
    if (filters.end) {
      constraints.push(where('createdAt', '<=', Timestamp.fromDate(filters.end)));
    }
    if (filters.cashierId) constraints.push(where('cashierId', '==', filters.cashierId));
    if (filters.status) constraints.push(where('status', '==', filters.status));
    constraints.push(orderBy('createdAt', 'desc'));
    if (filters.limit) constraints.push(fbLimit(filters.limit));

    const snap = await getDocs(query(this.salesCol(), ...constraints));
    return this.loadSalesWithItems(snap.docs.map((d) => d.data()));
  }

  watchToday(callback: (sales: Sale[]) => void, onError?: (e: Error) => void): Unsubscribe {
    const today = new Date();
    const q = query(
      this.salesCol(),
      where('createdAt', '>=', Timestamp.fromDate(startOfDay(today))),
      where('createdAt', '<=', Timestamp.fromDate(endOfDay(today))),
      orderBy('createdAt', 'desc'),
    );
    return onSnapshot(
      q,
      async (snap) => {
        try {
          const sales = await this.loadSalesWithItems(snap.docs.map((d) => d.data()));
          callback(sales);
        } catch (e) {
          onError?.(e as Error);
        }
      },
      (err) => onError?.(err),
    );
  }

  watchRecent(limit: number, callback: (sales: Sale[]) => void): Unsubscribe {
    const q = query(this.salesCol(), orderBy('createdAt', 'desc'));
    return onSnapshot(q, async (snap) => {
      const docs = snap.docs.slice(0, limit).map((d) => d.data());
      callback(await this.loadSalesWithItems(docs));
    });
  }

  async create(
    input: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'>,
    actorId: string,
  ): Promise<Sale> {
    if (input.items.length === 0) {
      throw new Error('Cannot complete a sale with an empty cart');
    }
    if (input.items.length > 200) {
      throw new Error(
        `This sale has ${input.items.length} lines — the max is 200. Split it into smaller sales.`,
      );
    }
    const now = new Date();
    const key = counterKey(now);
    const saleRef = doc(collection(this.db, FirestoreCollections.sales));
    const counterRef = doc(this.db, FirestoreCollections.settings, 'sale_counters');
    // Pre-allocate item ids so the tx is pure writes after the single counter read.
    const itemRefs = input.items.map(() =>
      doc(collection(this.db, FirestoreCollections.sales, saleRef.id, Subcollections.saleItems)),
    );

    await runTransaction(this.db, async (tx) => {
      // The only read — must precede every write.
      const counterSnap = await tx.get(counterRef);
      const seq =
        (counterSnap.exists() ? (counterSnap.data() as Record<string, number>)[key] ?? 0 : 0) + 1;
      const saleNumber = formatSaleNumber(now, seq);

      tx.set(saleRef, {
        saleNumber,
        discountType: input.discountType,
        paymentMethod: input.paymentMethod,
        tenders: input.tenders,
        amountReceived: input.amountReceived,
        changeGiven: input.changeGiven,
        status: input.status,
        cashierId: input.cashierId,
        cashierName: input.cashierName,
        laborLines: input.laborLines,
        mechanicId: input.mechanicId,
        mechanicName: input.mechanicName,
        draftId: input.draftId,
        notes: input.notes,
        voidedBy: null,
        voidedByName: null,
        voidReason: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      input.items.forEach((item, i) => {
        tx.set(itemRefs[i], {
          productId: item.productId,
          sku: item.sku,
          name: item.name,
          unitPrice: item.unitPrice,
          unitCost: item.unitCost,
          quantity: item.quantity,
          discountValue: item.discountValue,
          unit: item.unit,
        });
      });
      tx.set(counterRef, { [key]: seq }, { merge: true });
      // Stock decrement — the products update rule permits ONLY these 4 keys.
      for (const item of input.items) {
        tx.update(doc(this.db, FirestoreCollections.products, item.productId), {
          quantity: increment(-item.quantity),
          updatedAt: serverTimestamp(),
          updatedBy: actorId,
          updatedByName: input.cashierName,
        });
      }
    });

    const created = await this.getById(saleRef.id);
    if (!created) throw new Error('Failed to load the created sale');
    return created;
  }
  async voidSale(): Promise<void> {
    throw new Error('SaleRepository.voidSale not implemented yet (phase 11)');
  }

  private async loadItems(saleId: string) {
    const snap = await getDocs(this.itemsCol(saleId));
    return snap.docs.map((d) => d.data());
  }

  private async loadSalesWithItems(sales: Sale[]): Promise<Sale[]> {
    // Parallel item-loads keep the dashboard responsive on busy days. N+1
    // is fine for daily volume; reports paginate so this never grows
    // unbounded.
    const itemLists = await Promise.all(sales.map((s) => this.loadItems(s.id)));
    return sales.map((s, i) => ({ ...s, items: itemLists[i] }));
  }
}
