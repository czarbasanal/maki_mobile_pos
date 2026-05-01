// Mirror of lib/data/models/product_model.dart fromFirestore/toMap.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Product } from '@/domain/entities';
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
      searchKeywords: product.searchKeywords,
      baseSku: product.baseSku,
      variationNumber: product.variationNumber,
      barcode: product.barcode,
      category: product.category,
      imageUrl: product.imageUrl,
      notes: product.notes,
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
      searchKeywords: Array.isArray(d.searchKeywords) ? (d.searchKeywords as string[]) : [],
      baseSku: d.baseSku ?? null,
      variationNumber: d.variationNumber == null ? null : Number(d.variationNumber),
      barcode: d.barcode ?? null,
      category: d.category ?? null,
      imageUrl: d.imageUrl ?? null,
      notes: d.notes ?? null,
    };
  },
};
