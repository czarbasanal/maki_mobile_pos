// Mirror of lib/domain/repositories/void_request_repository.dart. The web
// files requests (cashier) and, since the admin queue moved here too, watches
// and resolves them.

import type { Unsubscribe } from './AuthRepository';
import type { VoidRequest, VoidRequestStatus } from '../entities';

export interface VoidRequestCreateInput {
  saleId: string;
  saleNumber: string;
  saleGrandTotal: number;
  requestedBy: string;
  requestedByName: string;
  requestedByRole: string;
  reason: string;
  /** Compact receipt line, or null to omit the field (mobile contract). */
  itemsSummary: string | null;
}

export interface VoidRequestResolveInput {
  requestId: string;
  /** Needed to release the per-sale pending claim alongside the status write. */
  saleId: string;
  status: Extract<VoidRequestStatus, 'approved' | 'rejected'>;
  resolvedBy: string;
  resolvedByName: string;
  rejectionReason?: string;
}

export interface VoidRequestRepository {
  /** Throws 'void-already-pending' (message text) when a request exists. */
  createRequest(input: VoidRequestCreateInput): Promise<void>;
  hasPendingForSale(saleId: string): Promise<boolean>;
  /** Every PENDING request, uncapped — a queue that drops old ones lies.
   *  Oldest first is the caller's sort; the query is an equality only so it
   *  needs no composite index. */
  watchPending(callback: (requests: VoidRequest[]) => void, onError?: (e: Error) => void): Unsubscribe;
  /** Resolved requests whose resolvedAt falls inside [range], newest first. */
  watchResolved(
    range: { start: Date; end: Date },
    callback: (requests: VoidRequest[]) => void,
    onError?: (e: Error) => void,
  ): Unsubscribe;
  /** Live queue, newest first, capped. Mirrors mobile's watchRequests. */
  watchRequests(
    callback: (requests: VoidRequest[]) => void,
    onError?: (e: Error) => void,
    limit?: number,
  ): Unsubscribe;
  /** Marks approved/rejected and releases the pending claim, in one batch. */
  resolve(input: VoidRequestResolveInput): Promise<void>;
  /** Clears the unread badge without resolving anything. */
  markAllRead(): Promise<void>;
}
