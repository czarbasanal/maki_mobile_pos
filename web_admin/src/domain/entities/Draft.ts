// Mirror of lib/domain/entities/draft_entity.dart.
import type { DiscountType } from '../enums';
import type { SaleItem } from './SaleItem';
import type { LaborLine } from './LaborLine';

export interface Draft {
  id: string;
  name: string;
  items: SaleItem[];
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  discountType: DiscountType;
  createdBy: string;
  createdByName: string;
  createdAt: Date;
  updatedAt: Date | null;
  updatedBy: string | null;
  isConverted: boolean;
  convertedToSaleId: string | null;
  convertedAt: Date | null;
  notes: string | null;
}
