// Mirror of lib/domain/entities/labor_line_entity.dart. Stored INLINE on the
// sale document's `laborLines` array (not a subcollection). Labor is full
// price, never discounted, and has zero cost (pure margin).
export interface LaborLine {
  id: string;
  description: string;
  fee: number;
}
