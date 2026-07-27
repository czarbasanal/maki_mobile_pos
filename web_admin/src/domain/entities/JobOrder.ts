// Mirror of lib/domain/entities/draft_entity.dart.
import type { DiscountType } from '../enums';
import type { SaleItem } from './SaleItem';
import type { LaborLine } from './LaborLine';
import type { FeeLine } from './FeeLine';

export interface JobOrder {
  id: string;
  name: string;
  items: SaleItem[];
  laborLines: LaborLine[];
  feeLines: FeeLine[];
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
