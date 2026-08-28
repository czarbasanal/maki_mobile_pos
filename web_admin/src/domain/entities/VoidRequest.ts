// Mirror of lib/domain/entities/void_request_entity.dart.

export const VoidRequestStatus = {
  pending: 'pending',
  approved: 'approved',
  rejected: 'rejected',
} as const;

export type VoidRequestStatus =
  (typeof VoidRequestStatus)[keyof typeof VoidRequestStatus];

/** Unknown values fall back to pending, matching mobile's fromValue. */
export function voidRequestStatusFromString(value: unknown): VoidRequestStatus {
  return value === 'approved' || value === 'rejected' ? value : 'pending';
}

/** A cashier's request to void a sale, awaiting admin approval. */
export interface VoidRequest {
  id: string;
  saleId: string;
  saleNumber: string;
  saleGrandTotal: number;
  requestedBy: string;
  requestedByName: string;
  requestedByRole: string;
  reason: string;
  status: VoidRequestStatus;
  /** False until an admin has seen it — drives the notification badge. */
  read: boolean;
  createdAt: Date;
  resolvedBy: string | null;
  resolvedByName: string | null;
  resolvedAt: Date | null;
  rejectionReason: string | null;
  /** Compact receipt line ("2× Plug, 1× Oil"), or null on older requests. */
  itemsSummary: string | null;
}

export function isPendingVoidRequest(r: VoidRequest): boolean {
  return r.status === 'pending';
}
