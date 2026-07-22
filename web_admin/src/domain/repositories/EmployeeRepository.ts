import type { Employee } from '@/domain/hr/types';
import type { Unsubscribe } from './AuthRepository';

export interface EmployeeCreateInput {
  name: string;
  dailyRate: number;
}

export interface EmployeeUpdateInput {
  name?: string;
  dailyRate?: number;
  isActive?: boolean;
}

export interface EmployeeRepository {
  watchAll(
    cb: (employees: Employee[]) => void,
    opts?: { includeInactive?: boolean },
    onError?: (err: Error) => void,
  ): Unsubscribe;
  create(input: EmployeeCreateInput): Promise<Employee>;
  update(id: string, input: EmployeeUpdateInput): Promise<void>;
}
