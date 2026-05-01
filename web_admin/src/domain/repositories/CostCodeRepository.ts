import type { CostCode } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface CostCodeRepository {
  get(): Promise<CostCode>;
  watch(callback: (cc: CostCode) => void): Unsubscribe;
  update(input: Omit<CostCode, 'updatedAt' | 'updatedBy'>, actorId: string): Promise<void>;
}
