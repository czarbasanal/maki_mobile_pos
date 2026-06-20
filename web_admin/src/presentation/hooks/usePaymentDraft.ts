import { useCallback, useState } from 'react';
import {
  amountReceivedFor,
  buildTenders,
  changeGivenFor,
  emptyPaymentDraft,
  paymentError,
  paymentLabel,
  type DigitalMethod,
  type DpMethod,
  type PaymentDraft,
  type PaymentMode,
} from '@/domain/sales/payment';

/** Holds the transient payment entry for one checkout. Reset after each sale;
 *  switching mode clears entered amounts so a stale value can't carry over. */
export function usePaymentDraft(grandTotal: number) {
  const [draft, setDraft] = useState<PaymentDraft>(emptyPaymentDraft);

  const setMode = useCallback(
    (mode: PaymentMode) => setDraft((d) => ({ ...d, mode, cashReceived: 0, splitAmount: 0 })),
    [],
  );
  const setCashReceived = useCallback(
    (cashReceived: number) => setDraft((d) => ({ ...d, cashReceived })),
    [],
  );
  const setDigitalMethod = useCallback(
    (digitalMethod: DigitalMethod) => setDraft((d) => ({ ...d, digitalMethod })),
    [],
  );
  const setDpMethod = useCallback(
    (dpMethod: DpMethod) => setDraft((d) => ({ ...d, dpMethod })),
    [],
  );
  const setSplitAmount = useCallback(
    (splitAmount: number) => setDraft((d) => ({ ...d, splitAmount })),
    [],
  );
  const reset = useCallback(() => setDraft(emptyPaymentDraft), []);

  const error = paymentError(draft, grandTotal);
  return {
    draft,
    setMode,
    setCashReceived,
    setDigitalMethod,
    setDpMethod,
    setSplitAmount,
    reset,
    paymentMethod: paymentLabel(draft.mode),
    tenders: buildTenders(draft, grandTotal),
    amountReceived: amountReceivedFor(draft, grandTotal),
    changeGiven: changeGivenFor(draft, grandTotal),
    error,
    isValid: error === null,
  };
}
