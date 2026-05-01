import type { Supplier } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface SupplierRepository {
  getById(id: string): Promise<Supplier | null>;
  list(): Promise<Supplier[]>;
  watchAll(callback: (suppliers: Supplier[]) => void): Unsubscribe;
  create(input: Omit<Supplier, 'id' | 'createdAt' | 'updatedAt' | 'productCount' | 'totalInventoryValue'>, actorId: string): Promise<Supplier>;
  update(id: string, input: Partial<Omit<Supplier, 'id' | 'createdAt'>>, actorId: string): Promise<void>;
  deactivate(id: string, actorId: string): Promise<void>;
}
