import { useMutation } from '@tanstack/react-query';
import { useDraftRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Draft, LaborLine, SaleItem } from '@/domain/entities';
import type { DiscountType } from '@/domain/enums/DiscountType';

export interface SaveDraftInput {
  draftId: string | null;
  name: string;
  items: SaleItem[];
  discountType: DiscountType;
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
}

/** Create a new draft or update the active one (resume → edit → save). */
export function useSaveDraft() {
  const repo = useDraftRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Draft | void, Error, SaveDraftInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      if (input.draftId) {
        await repo.update(
          input.draftId,
          {
            name: input.name,
            items: input.items,
            discountType: input.discountType,
            laborLines: input.laborLines,
            mechanicId: input.mechanicId,
            mechanicName: input.mechanicName,
          },
          actor.id,
        );
        return;
      }
      const cashierName = actor.displayName.trim() || actor.email;
      return repo.create({
        name: input.name,
        items: input.items,
        discountType: input.discountType,
        laborLines: input.laborLines,
        mechanicId: input.mechanicId,
        mechanicName: input.mechanicName,
        createdBy: actor.id,
        createdByName: cashierName,
        updatedBy: null,
        isConverted: false,
        convertedToSaleId: null,
        convertedAt: null,
        notes: null,
      });
    },
  });
}

export function useDeleteDraft() {
  const repo = useDraftRepo();
  return useMutation<void, Error, string>({ mutationFn: (id) => repo.delete(id) });
}

export function useMarkConverted() {
  const repo = useDraftRepo();
  return useMutation<void, Error, { id: string; saleId: string }>({
    mutationFn: ({ id, saleId }) => repo.markConverted(id, saleId),
  });
}
