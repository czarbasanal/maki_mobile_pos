import { useMutation } from '@tanstack/react-query';
import { useSupplierRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Supplier } from '@/domain/entities';
import type { TransactionType } from '@/domain/enums';

export interface SupplierCreateInput {
  name: string;
  address: string | null;
  contactPerson: string | null;
  contactNumber: string | null;
  alternativeNumber: string | null;
  email: string | null;
  transactionType: TransactionType;
  notes: string | null;
}

export function useCreateSupplier() {
  const repo = useSupplierRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Supplier, Error, SupplierCreateInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(
        {
          ...input,
          isActive: true,
          createdBy: actor.id,
          updatedBy: actor.id,
        },
        actor.id,
      );
    },
  });
}

export interface SupplierUpdateInput {
  id: string;
  name?: string;
  address?: string | null;
  contactPerson?: string | null;
  contactNumber?: string | null;
  alternativeNumber?: string | null;
  email?: string | null;
  transactionType?: TransactionType;
  notes?: string | null;
  isActive?: boolean;
}

export function useUpdateSupplier() {
  const repo = useSupplierRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, SupplierUpdateInput>({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
    },
  });
}

export function useDeactivateSupplier() {
  const repo = useSupplierRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, string>({
    mutationFn: async (id) => {
      if (!actor) throw new Error('Not signed in');
      await repo.deactivate(id, actor.id);
    },
  });
}
