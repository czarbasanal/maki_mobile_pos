// Mirror of lib/domain/repositories/void_request_repository.dart's WRITE
// surface. The web only files requests (cashier) and checks for a pending
// one — the approval queue stays on the admin's phone.

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

export interface VoidRequestRepository {
  /** Throws 'void-already-pending' (message text) when a request exists. */
  createRequest(input: VoidRequestCreateInput): Promise<void>;
  hasPendingForSale(saleId: string): Promise<boolean>;
}
