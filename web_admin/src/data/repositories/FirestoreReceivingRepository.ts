import {
  collection,
  doc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  Timestamp,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository, ProductCreateInput } from '@/domain/repositories/ProductRepository';
import type {
  BulkReceiveInput,
  ReceivingRepository,
  ReceivingResult,
} from '@/domain/repositories/ReceivingRepository';
import type { Receiving } from '@/domain/entities';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { encodeCostCode } from '@/domain/entities';
import { generateSku } from '@/domain/products/sku';
import { generateSearchKeywords } from '@/domain/products/searchKeywords';
import { nextVariationNumber, variationSku } from '@/domain/receiving/variations';

interface BuiltItem {
  productId: string;
  sku: string;
  name: string;
  quantity: number;
  unit: string;
  unitCost: number;
  costCode: string;
  isNewVariation: boolean;
  newProductId: string | null;
}

export class FirestoreReceivingRepository implements ReceivingRepository {
  constructor(
    private readonly db: Firestore,
    private readonly products: ProductRepository,
  ) {}

  async bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult> {
    const { rows, supplier, cipher, actor } = input;
    const referenceNumber = await this.generateReferenceNumber();

    const items: BuiltItem[] = [];
    const increments = new Map<string, number>(); // productId -> qty to add
    const failed: ReceivingResult['failed'] = [];
    const knownSkus = input.products.map((p) => p.sku);
    let newProducts = 0;
    let variations = 0;

    for (const c of rows) {
      if (c.status === 'error') continue;
      const r = c.row;
      try {
        if (c.status === 'match' && c.existing) {
          increments.set(c.existing.id, (increments.get(c.existing.id) ?? 0) + r.quantity);
          items.push({
            productId: c.existing.id, sku: c.existing.sku, name: c.existing.name,
            quantity: r.quantity, unit: c.existing.unit, unitCost: c.existing.cost,
            costCode: c.existing.costCode, isNewVariation: false, newProductId: null,
          });
        } else if (c.status === 'mismatch' && c.existing) {
          const base = c.existing.baseSku ?? c.existing.sku;
          const n = nextVariationNumber(base, knownSkus);
          const sku = variationSku(base, n);
          knownSkus.push(sku);
          const costCode = encodeCostCode(cipher, r.cost);
          const created = await this.products.create(
            this.productInput({
              sku, name: c.existing.name, cost: r.cost, costCode, price: c.existing.price,
              quantity: r.quantity, reorderLevel: c.existing.reorderLevel, unit: c.existing.unit,
              category: c.existing.category, supplierId: c.existing.supplierId,
              supplierName: c.existing.supplierName, baseSku: base, variationNumber: n, actor,
            }),
            actor.id,
          );
          await this.products.recordPriceChange(created.id, {
            price: c.existing.price, cost: r.cost, changedBy: actor.id, reason: 'receiving',
          });
          variations += 1;
          items.push({
            productId: c.existing.id, sku, name: c.existing.name, quantity: r.quantity,
            unit: c.existing.unit, unitCost: r.cost, costCode, isNewVariation: true,
            newProductId: created.id,
          });
        } else {
          // new
          const sku = r.autoGenerateSku ? generateSku(r.name) : r.sku;
          const costCode = encodeCostCode(cipher, r.cost);
          const created = await this.products.create(
            this.productInput({
              sku, name: r.name, cost: r.cost, costCode, price: r.price, quantity: r.quantity,
              reorderLevel: r.reorderLevel, unit: r.unit, category: r.category,
              supplierId: supplier?.id ?? null, supplierName: supplier?.name ?? null,
              baseSku: null, variationNumber: null, actor,
            }),
            actor.id,
          );
          await this.products.recordPriceChange(created.id, {
            price: r.price, cost: r.cost, changedBy: actor.id, reason: 'Initial price',
          });
          newProducts += 1;
          items.push({
            productId: created.id, sku: created.sku, name: r.name, quantity: r.quantity,
            unit: r.unit, unitCost: r.cost, costCode, isNewVariation: false, newProductId: null,
          });
        }
      } catch (e) {
        failed.push({ row: r.rowNumber, message: (e as Error).message });
      }
    }

    const batch = writeBatch(this.db);
    for (const [productId, delta] of increments) {
      batch.update(doc(this.db, FirestoreCollections.products, productId), {
        quantity: increment(delta),
        updatedBy: actor.id,
        updatedByName: actor.name,
        updatedAt: serverTimestamp(),
      });
    }
    const totalQuantity = items.reduce((n, it) => n + it.quantity, 0);
    const totalCost = items.reduce((n, it) => n + it.unitCost * it.quantity, 0);
    batch.set(doc(collection(this.db, FirestoreCollections.receivings)), {
      referenceNumber,
      supplierId: supplier?.id ?? null,
      supplierName: supplier?.name ?? null,
      items: items.map((it) => ({ ...it, notes: null })),
      totalCost,
      totalQuantity,
      status: 'completed',
      notes: null,
      createdBy: actor.id,
      createdByName: actor.name,
      completedBy: actor.id,
      createdAt: serverTimestamp(),
      completedAt: serverTimestamp(),
    });
    await batch.commit();

    return { referenceNumber, received: items.length, newProducts, variations, failed };
  }

  // Receiving-history methods land in phase 8 (the receiving list/detail views).
  async getById(): Promise<Receiving | null> {
    throw new Error('ReceivingRepository.getById not implemented yet (phase 8)');
  }
  async list(): Promise<Receiving[]> {
    throw new Error('ReceivingRepository.list not implemented yet (phase 8)');
  }
  watchAll(): Unsubscribe {
    throw new Error('ReceivingRepository.watchAll not implemented yet (phase 8)');
  }
  async create(): Promise<Receiving> {
    throw new Error('ReceivingRepository.create not implemented yet (phase 8)');
  }
  async complete(): Promise<void> {
    throw new Error('ReceivingRepository.complete not implemented yet (phase 8)');
  }

  private productInput(p: {
    sku: string; name: string; cost: number; costCode: string; price: number; quantity: number;
    reorderLevel: number; unit: string; category: string | null; supplierId: string | null;
    supplierName: string | null; baseSku: string | null; variationNumber: number | null;
    actor: { id: string; name: string };
  }): ProductCreateInput {
    return {
      sku: p.sku, name: p.name, costCode: p.costCode, cost: p.cost, price: p.price,
      quantity: p.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
      supplierId: p.supplierId, supplierName: p.supplierName, isActive: true,
      createdBy: p.actor.id, updatedBy: p.actor.id,
      createdByName: p.actor.name, updatedByName: p.actor.name,
      searchKeywords: generateSearchKeywords([p.sku, p.name, p.category]),
      baseSku: p.baseSku, variationNumber: p.variationNumber, barcode: null,
      category: p.category, imageUrl: null, notes: null,
    };
  }

  private async generateReferenceNumber(): Promise<string> {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    const snap = await getDocs(
      query(
        collection(this.db, FirestoreCollections.receivings),
        where('createdAt', '>=', Timestamp.fromDate(start)),
        where('createdAt', '<', Timestamp.fromDate(end)),
      ),
    );
    const seq = snap.size + 1;
    const date = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
      now.getDate(),
    ).padStart(2, '0')}`;
    return `RCV-${date}-${String(seq).padStart(3, '0')}`;
  }
}
