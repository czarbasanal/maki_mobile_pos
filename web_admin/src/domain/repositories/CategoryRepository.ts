import type { Category } from '../entities';
import type { CategoryKind } from '../categories/categoryKind';
import type { Unsubscribe } from './AuthRepository';

export interface CategoryUpdateInput {
  name?: string;
  isActive?: boolean;
}

export interface CategoryRepository {
  list(kind: CategoryKind, opts?: { includeInactive?: boolean }): Promise<Category[]>;
  watchAll(
    kind: CategoryKind,
    cb: (categories: Category[]) => void,
    opts?: { includeInactive?: boolean },
  ): Unsubscribe;
  create(kind: CategoryKind, name: string, actorId: string): Promise<Category>;
  update(kind: CategoryKind, id: string, input: CategoryUpdateInput, actorId: string): Promise<void>;
  /**
   * Hard-deletes the category doc. Past records that reference it (a sale
   * item, a product) keep the name they had at the time — nothing else is
   * touched. Use `update(..., { isActive: false })` for a reversible hide.
   */
  delete(kind: CategoryKind, id: string): Promise<void>;
  /**
   * Plain (non-claiming) read of `category_codes/{categoryCode}.nextSequence`
   * — used by the product form to preview the SKU the create transaction
   * would claim, without reserving it. Throws if the code is unknown.
   */
  peekNextSequence(categoryCode: string): Promise<number>;
}
