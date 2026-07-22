import type { Payslip } from '@/domain/hr/types';
import type { Unsubscribe } from './AuthRepository';

export interface PayslipRepository {
  watchAll(cb: (payslips: Payslip[]) => void): Unsubscribe;
  getById(id: string): Promise<Payslip | null>;
  create(input: Omit<Payslip, 'id' | 'createdAt'>): Promise<string>;
  delete(id: string): Promise<void>;
}
