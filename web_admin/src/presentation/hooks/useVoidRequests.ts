// The admin void-request queue, mirroring mobile's voidRequestsProvider +
// unreadVoidRequestCountProvider + ApproveVoidRequestUseCase.
//
// Web voids carry no password re-prompt (the admin is authenticated in the
// browser session), matching how SaleDetailPage already voids directly.

import { useMemo } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import {
  useActivityLogRepo,
  useSaleRepo,
  useVoidRequestRepo,
} from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, isPendingVoidRequest, type VoidRequest } from '@/domain/entities';

export interface VoidRequestQueue {
  requests: VoidRequest[];
  pending: VoidRequest[];
  /** Badge count: unread AND still pending — a resolved one is history. */
  unreadCount: number;
  isLoading: boolean;
  error: Error | null;
}

export function useVoidRequests(): VoidRequestQueue {
  const repo = useVoidRequestRepo();
  const { data, error, isLoading } = useFirestoreSubscription<VoidRequest[]>(
    (onData, onError) => repo.watchRequests(onData, onError),
    [repo],
    'voidRequests',
  );
  const requests = useMemo(() => data ?? [], [data]);
  return useMemo(
    () => ({
      requests,
      pending: requests.filter(isPendingVoidRequest),
      unreadCount: requests.filter((r) => !r.read && isPendingVoidRequest(r)).length,
      isLoading,
      error,
    }),
    [requests, isLoading, error],
  );
}

export interface ResolveVoidRequestInput {
  request: VoidRequest;
  approve: boolean;
  rejectionReason?: string;
}

/** Approve (void the sale, then mark approved) or reject (mark only). */
export function useResolveVoidRequest() {
  const voidRequestRepo = useVoidRequestRepo();
  const saleRepo = useSaleRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();

  return useMutation<void, Error, ResolveVoidRequestInput>({
    mutationFn: async ({ request, approve, rejectionReason }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || actor.email;

      if (approve) {
        // Void FIRST and let a failure propagate. A request marked approved
        // whose sale never voided leaves the money standing with nothing left
        // in the queue to notice it by. Mirrors ApproveVoidRequestUseCase.
        await saleRepo.voidSale(request.saleId, request.reason, actor.id, actorName);
      }

      await voidRequestRepo.resolve({
        requestId: request.id,
        saleId: request.saleId,
        status: approve ? 'approved' : 'rejected',
        resolvedBy: actor.id,
        resolvedByName: actorName,
        ...(approve ? {} : { rejectionReason }),
      });

      logActivity(activityLogRepo, () => ({
        type: ActivityType.voidSale,
        action: `${approve ? 'Approved' : 'Rejected'} void request for sale ${request.saleNumber}`,
        details: approve
          ? `Reason: ${request.reason}, Amount: ₱${request.saleGrandTotal.toFixed(2)}`
          : `Rejected: ${rejectionReason ?? '—'}`,
        entityId: request.saleId,
        entityType: 'sale',
      }));
    },
    onSuccess: (_data, { request }) => {
      qc.invalidateQueries({ queryKey: ['sales', request.saleId] });
      qc.invalidateQueries({ queryKey: ['voidRequestPending', request.saleId] });
      // A voided sale drops out of report totals.
      qc.invalidateQueries({ queryKey: ['reports'] });
    },
  });
}

/** Clears the badge without resolving anything (opening the panel). */
export function useMarkVoidRequestsRead() {
  const repo = useVoidRequestRepo();
  return useMutation<void, Error, void>({
    mutationFn: () => repo.markAllRead(),
  });
}
