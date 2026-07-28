import { createCartStore } from './cartStore';

/** A cart-store instance dedicated to editing one job order in place, so the live
 *  POS cart is never disturbed. Hydrated via loadJobOrder on the job order-edit page. */
export const useJobOrderEditStore = createCartStore();
