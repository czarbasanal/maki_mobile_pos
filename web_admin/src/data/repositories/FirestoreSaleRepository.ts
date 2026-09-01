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
import { SaleStatus } from '@/domain/enums/SaleStatus';
import { jobOrderConversionOutcome } from '@/domain/sales/jobOrderConversion';
import { phDayInt } from '@/core/utils/businessDay';

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
    saleId?: string,
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
    // A caller-minted checkout id makes the write idempotent: the doc id IS
    // the dedupe key, so a network retry can never record the sale twice
    // (mobile's DuplicateSaleException guard, re-expressed).
    const saleRef = saleId
      ? doc(this.db, FirestoreCollections.sales, saleId)
      : doc(collection(this.db, FirestoreCollections.sales));
    const counterRef = doc(this.db, FirestoreCollections.settings, 'sale_counters');
    // Pre-allocate item ids so the tx is pure writes after the single counter read.
    const itemRefs = input.items.map(() =>
      doc(collection(this.db, FirestoreCollections.sales, saleRef.id, Subcollections.saleItems)),
    );
    const jobOrderRef = input.jobOrderId
      ? doc(this.db, FirestoreCollections.jobOrders, input.jobOrderId)
      : null;
    const drawerStateRef = doc(this.db, FirestoreCollections.drawerState, 'state');

    await runTransaction(this.db, async (tx) => {
      // Reads first — must precede every write.
      if (saleId) {
        const existingSale = await tx.get(saleRef);
        if (existingSale.exists()) {
          // Already recorded by a previous attempt — write nothing; the
          // reload below returns the recorded sale as this call's result.
          return;
        }
      }
      const counterSnap = await tx.get(counterRef);
      const jobOrderSnap = jobOrderRef ? await tx.get(jobOrderRef) : null;

      // A resumed job order converts atomically with the sale; an already-converted
      // job order aborts the whole sale (prevents a duplicate); a deleted job order is
      // skipped so the sale still commits.
      const outcome = jobOrderSnap
        ? jobOrderConversionOutcome(jobOrderSnap.exists(), jobOrderSnap.get('isConverted') === true)
        : 'skip';
      if (outcome === 'abort') {
        throw new Error('This Job Order was already billed out');
      }

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
        feeLines: input.feeLines,
        mechanicId: input.mechanicId,
        mechanicName: input.mechanicName,
        motorcycleModel: input.motorcycleModel ?? null,
        jobOrderId: input.jobOrderId,
        notes: input.notes,
        voidedBy: null,
        voidedByName: null,
        voidReason: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      // Stamp the business-day rollover marker (mirrors mobile's
      // sale_repository_impl.dart). Reuses the same `now` already used above
      // for the counter's dateKey, so this matches the rules' UTC+8 phDay().
      // Unlike mobile's businessDayInt (which reads the device's local
      // DateTime fields and so assumes a PH-local device clock), phDayInt
      // does epoch (UTC) math with a fixed +8h offset — it's correct
      // regardless of the browser's timezone.
      tx.set(drawerStateRef, { lastSaleDay: phDayInt(now) }, { merge: true });
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
          // Keep this list in sync with saleItemConverter.toFirestore — see
          // FirestoreSaleRepository.test.ts's "item write shape" tests,
          // which pin the two against each other.
          optionId: item.optionId,
          optionLabel: item.optionLabel,
          optionPieces: item.optionPieces,
          optionPrice: item.optionPrice,
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
      // Mark the source job order converted, atomically with the sale.
      if (jobOrderRef && outcome === 'convert') {
        tx.update(jobOrderRef, {
          isConverted: true,
          convertedToSaleId: saleRef.id,
          convertedAt: serverTimestamp(),
        });
      }
    });

    // Covers both the fresh write and the already-recorded retry path.
    const created = await this.getById(saleRef.id);
    if (!created) throw new Error('Failed to load the recorded sale');
    return created;
  }
  async voidSale(
    id: string,
    reason: string,
    actorId: string,
    actorName: string,
  ): Promise<void> {
    // Items are immutable once written, so loading them before the transaction
    // is safe (a subcollection query can't run inside a transaction anyway).
    const items = await this.loadItems(id);
    const saleRef = doc(this.db, FirestoreCollections.sales, id);

    await runTransaction(this.db, async (tx) => {
      const snap = await tx.get(saleRef); // the only read — precedes every write
      if (!snap.exists()) throw new Error('Sale not found');
      const status = snap.get('status');
      if (status === SaleStatus.voided) throw new Error('This sale is already voided');
      // Only a completed sale decremented stock, so only a completed sale may be
      // voided + restocked (keeps the void invariant aligned with canVoidSale).
      if (status !== SaleStatus.completed) {
        throw new Error('Only a completed sale can be voided');
      }

      tx.update(saleRef, {
        status: SaleStatus.voided,
        voidedAt: serverTimestamp(),
        voidedBy: actorId,
        voidedByName: actorName,
        voidReason: reason,
        updatedAt: serverTimestamp(),
        updatedBy: actorId,
      });

      // Stock restore — the reverse of the create() decrement. The products
      // update rule permits ONLY these 4 keys.
      for (const item of items) {
        tx.update(doc(this.db, FirestoreCollections.products, item.productId), {
          quantity: increment(item.quantity),
          updatedAt: serverTimestamp(),
          updatedBy: actorId,
          updatedByName: actorName,
        });
      }
    });
  }

  private async loadItems(saleId: string) {
    const snap = await getDocs(this.itemsCol(saleId));
    return snap.docs.map((d) => d.data());
  }

  private async loadSalesWithItems(sales: Sale[]): Promise<Sale[]> {
    // Item subcollections load in parallel chunks of 20, mirroring the
    // mobile repository: unbounded fan-out melts large windows (reports,
    // reorder suggestions), while per-chunk Promise.all preserves order.
    const chunkSize = 20;
    const out: Sale[] = [];
    for (let i = 0; i < sales.length; i += chunkSize) {
      const chunk = sales.slice(i, i + chunkSize);
      const itemLists = await Promise.all(chunk.map((s) => this.loadItems(s.id)));
      out.push(...chunk.map((s, j) => ({ ...s, items: itemLists[j] })));
    }
    return out;
  }
}
