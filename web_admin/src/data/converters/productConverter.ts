// Mirror of lib/data/models/product_model.dart fromFirestore/toMap.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Product, SellingOption } from '@/domain/entities';
import { parseBarcodes } from '@/domain/products/barcodes';
import { parseSellingOptions, serializeSellingOptions } from '@/domain/products/sellingOptions';
import { requireDate, toDate } from './timestamps';

export const productConverter: FirestoreDataConverter<Product> = {
  toFirestore(product) {
    return {
      sku: product.sku,
      name: product.name,
      costCode: product.costCode,
      cost: product.cost,
      price: product.price,
      quantity: product.quantity,
      reorderLevel: product.reorderLevel,
      unit: product.unit,
      supplierId: product.supplierId,
      supplierName: product.supplierName,
      isActive: product.isActive,
      createdBy: product.createdBy,
      updatedBy: product.updatedBy,
      createdByName: product.createdByName,
      updatedByName: product.updatedByName,
      searchKeywords: product.searchKeywords,
      baseSku: product.baseSku,
      variationNumber: product.variationNumber,
      barcodes: product.barcodes,
      // Cast — toFirestore receives WithFieldValue<T> by default, but we
      // never feed FieldValue placeholders through this code path.
      sellingOptions: serializeSellingOptions(product.sellingOptions as SellingOption[]),
      category: product.category,
      imageUrl: product.imageUrl,
      notes: product.notes,
      tagIds: product.tagIds,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Product {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      sku: d.sku ?? '',
      name: d.name ?? '',
      costCode: d.costCode ?? '',
      cost: Number(d.cost ?? 0),
      price: Number(d.price ?? 0),
      quantity: Number(d.quantity ?? 0),
      reorderLevel: Number(d.reorderLevel ?? 0),
      unit: d.unit ?? 'pcs',
      supplierId: d.supplierId ?? null,
      supplierName: d.supplierName ?? null,
      isActive: d.isActive ?? true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
      createdByName: d.createdByName ?? null,
      updatedByName: d.updatedByName ?? null,
      searchKeywords: Array.isArray(d.searchKeywords) ? (d.searchKeywords as string[]) : [],
      baseSku: d.baseSku ?? null,
      variationNumber: d.variationNumber == null ? null : Number(d.variationNumber),
      barcodes: parseBarcodes(d),
      sellingOptions: parseSellingOptions(d.sellingOptions),
      category: d.category ?? null,
      imageUrl: d.imageUrl ?? null,
      notes: d.notes ?? null,
      tagIds: Array.isArray(d.tagIds)
        ? d.tagIds.filter((t: unknown): t is string => typeof t === 'string')
        : [],
    };
  },
};
