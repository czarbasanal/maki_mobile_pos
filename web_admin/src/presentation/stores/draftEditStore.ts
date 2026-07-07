import { createCartStore } from './cartStore';

/** A cart-store instance dedicated to editing one draft in place, so the live
 *  POS cart is never disturbed. Hydrated via loadDraft on the draft-edit page. */
export const useDraftEditStore = createCartStore();
