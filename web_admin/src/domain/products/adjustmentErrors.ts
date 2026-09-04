// Thrown by FirestoreProductRepository.adjustStockAudited's transaction —
// the three abort paths, in the order the transaction checks them:
// inactive -> stale on-hand -> negative result. The dialog (Task 6) catches
// StaleOnHandError specifically to offer a "refresh and retry" recovery;
// the other two are terminal.

/** The product's on-hand quantity read inside the transaction didn't match
 *  what the dialog started from — someone else adjusted stock concurrently.
 *  Carries the CURRENT quantity so the caller can re-seed the form. */
export class StaleOnHandError extends Error {
  constructor(public readonly currentOnHand: number) {
    super('stale-on-hand');
  }
}

/** The product was deactivated between the dialog opening and the submit
 *  landing — a deactivated product can't be stock-adjusted. */
export class ProductInactiveError extends Error {
  constructor() {
    super('product-inactive');
  }
}

/** The resolved after-quantity would be negative. Only reachable via a race
 *  (the dialog validates this client-side already). */
export class NegativeResultError extends Error {
  constructor() {
    super('negative-result');
  }
}
