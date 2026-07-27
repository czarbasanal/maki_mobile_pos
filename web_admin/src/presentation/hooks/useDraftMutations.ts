import { useMutation, useQueryClient } from '@tanstack/react-query';
import { queryKeys } from '@/infrastructure/query/queryKeys';
import { useActivityLogRepo, useDraftRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type Draft, type FeeLine, type LaborLine, type SaleItem } from '@/domain/entities';
import type { DiscountType } from '@/domain/enums/DiscountType';

export interface SaveDraftInput {
  draftId: string | null;
  name: string;
  items: SaleItem[];
  discountType: DiscountType;
  laborLines: LaborLine[];
  feeLines: FeeLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  notes: string | null;
}

/** Create a new draft or update the active one (resume → edit → save). */
export function useSaveDraft() {
  const repo = useDraftRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<Draft | void, Error, SaveDraftInput>({
    // Without this, staleTime (60s) lets JobOrderEditPage rehydrate from the
    // pre-save cache — the user sees their save reverted, and saving again
    // persists the stale copy over the new one.
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: queryKeys.drafts.all });
    },
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
            feeLines: input.feeLines,
            mechanicId: input.mechanicId,
            mechanicName: input.mechanicName,
            notes: input.notes,
          },
          actor.id,
        );
        logActivity(activityLogRepo, () => ({
          type: ActivityType.other,
          action: `Saved job order ${input.name}`,
          entityId: input.draftId as string,
          entityType: 'draft',
        }));
        return;
      }
      const cashierName = actor.displayName.trim() || actor.email;
      const created = await repo.create({
        name: input.name,
        items: input.items,
        discountType: input.discountType,
        laborLines: input.laborLines,
        feeLines: input.feeLines,
        mechanicId: input.mechanicId,
        mechanicName: input.mechanicName,
        createdBy: actor.id,
        createdByName: cashierName,
        updatedBy: null,
        isConverted: false,
        convertedToSaleId: null,
        convertedAt: null,
        notes: input.notes,
      });
      logActivity(activityLogRepo, () => ({
        type: ActivityType.other,
        action: `Saved job order ${created.name}`,
        entityId: created.id,
        entityType: 'draft',
      }));
      return created;
    },
  });
}

export interface DeleteDraftInput {
  id: string;
  name: string;
}

export function useDeleteDraft() {
  const repo = useDraftRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, DeleteDraftInput>({
    mutationFn: async ({ id, name }) => {
      await repo.delete(id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.other,
        action: `Deleted job order ${name}`,
        entityId: id,
        entityType: 'draft',
      }));
    },
  });
}
