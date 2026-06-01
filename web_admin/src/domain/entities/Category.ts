// Mirror of lib/data/models/category_model.dart (CategoryEntity). Used for the
// admin-managed product_categories / units / expense_categories / void_reasons.
export interface Category {
  id: string;
  name: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
