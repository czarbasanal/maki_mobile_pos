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
}
