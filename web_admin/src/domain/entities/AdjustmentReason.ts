// Configurable reasons for stock adjustments. Each carries a flag indicating
// whether a note must be provided when that reason is selected.
// Mirror of lib/domain/entities/adjustment_reason_entity.dart.
export interface AdjustmentReason {
  id: string;
  name: string;           // display + match key
  requiresNote: boolean;  // true when a note is mandatory for this reason
  isActive: boolean;      // soft-delete; inactive reasons disappear, ids stay in records
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
