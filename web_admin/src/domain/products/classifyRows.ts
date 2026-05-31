import type { Product, Supplier } from '../entities';
import type {
  ProductCreateInput,
  ProductUpdateInput,
} from '../repositories/ProductRepository';
import { generateSku } from './sku';
import { generateSearchKeywords } from './searchKeywords';
import type { ParsedRow } from './importRows';

export type RowStatus = 'new' | 'existing' | 'error';
export type RowAction = 'insert' | 'update' | 'skip';

export interface ClassifiedRow {
  parsed: ParsedRow;
  status: RowStatus;
  matchedProductId: string | null;
  supplierId: string | null;
  supplierMatched: boolean;
  defaultAction: RowAction;
}

function productKey(name: string, category: string | null): string {
  return `${name.trim().toLowerCase()}|${(category ?? '').trim().toLowerCase()}`;
}

export function classifyRows(
  parsed: ParsedRow[],
  existing: Product[],
  suppliers: Supplier[],
): ClassifiedRow[] {
  const productIndex = new Map<string, Product[]>();
  for (const p of existing) {
    const key = productKey(p.name, p.category);
    const list = productIndex.get(key);
    if (list) list.push(p);
    else productIndex.set(key, [p]);
  }
  const supplierIndex = new Map<string, Supplier>();
  for (const s of suppliers) supplierIndex.set(s.name.trim().toLowerCase(), s);

  return parsed.map((row): ClassifiedRow => {
    let supplierId: string | null = null;
    let supplierMatched = false;
    if (row.supplierName) {
      const s = supplierIndex.get(row.supplierName.trim().toLowerCase());
      if (s) {
        supplierId = s.id;
        supplierMatched = true;
      } else {
        row.warnings.push(`Supplier "${row.supplierName}" not found — keeping the name only.`);
      }
    }

    if (row.errors.length > 0) {
      return { parsed: row, status: 'error', matchedProductId: null, supplierId, supplierMatched, defaultAction: 'skip' };
    }

    const matches = productIndex.get(productKey(row.name, row.category)) ?? [];
    if (matches.length > 0) {
      if (matches.length > 1) {
        row.warnings.push(
          `${matches.length} existing products match this name + category; the first will be updated.`,
        );
      }
      return { parsed: row, status: 'existing', matchedProductId: matches[0].id, supplierId, supplierMatched, defaultAction: 'update' };
    }
    return { parsed: row, status: 'new', matchedProductId: null, supplierId, supplierMatched, defaultAction: 'insert' };
  });
}

export function toCreateInput(
  row: ClassifiedRow,
  actor: { id: string; name: string },
): ProductCreateInput {
  const sku = generateSku(row.parsed.name);
  return {
    sku,
    name: row.parsed.name,
    costCode: row.parsed.code,
    cost: row.parsed.cost,
    price: row.parsed.price,
    quantity: row.parsed.quantity,
    reorderLevel: row.parsed.reorderLevel,
    unit: row.parsed.unit,
    supplierId: row.supplierId,
    supplierName: row.parsed.supplierName,
    isActive: true,
    createdBy: actor.id,
    updatedBy: actor.id,
    createdByName: actor.name,
    updatedByName: actor.name,
    searchKeywords: generateSearchKeywords([sku, row.parsed.name, row.parsed.category]),
    baseSku: null,
    variationNumber: null,
    barcode: null,
    category: row.parsed.category,
    imageUrl: null,
    notes: null,
  };
}

export function toUpdateInput(
  row: ClassifiedRow,
  actor: { id: string; name: string },
): ProductUpdateInput {
  return {
    costCode: row.parsed.code,
    cost: row.parsed.cost,
    price: row.parsed.price,
    quantity: row.parsed.quantity,
    reorderLevel: row.parsed.reorderLevel,
    unit: row.parsed.unit,
    supplierId: row.supplierId,
    supplierName: row.parsed.supplierName,
    updatedBy: actor.id,
    updatedByName: actor.name,
  };
}
