import { useCallback, useState } from 'react';
import {
  amountReceivedFor,
  buildTenders,
  changeGivenFor,
  paymentError,
  paymentLabel,
  type DigitalMethod,
  type DpMethod,
  type PaymentDraft,
  type PaymentMode,
} from '@/domain/sales/payment';

/** Holds the transient payment entry for one checkout. The two money fields are
 *  kept as raw STRINGS (so a cashier can type "99.99" without the decimal point
 *  being eaten mid-entry); the numeric `PaymentDraft` the pure helpers consume
 *  is derived from them. Reset after each sale; switching mode clears the
 *  entered amounts so a stale value can't carry over. */
export function usePaymentDraft(grandTotal: number) {
  const [mode, setModeState] = useState<PaymentMode>('cash');
  const [digitalMethod, setDigitalMethod] = useState<DigitalMethod>('gcash');
  const [dpMethod, setDpMethod] = useState<DpMethod>('cash');
  const [cashText, setCashText] = useState('');
  const [splitText, setSplitText] = useState('');

  const setMode = useCallback((m: PaymentMode) => {
    setModeState(m);
    setCashText('');
    setSplitText('');
  }, []);

  const reset = useCallback(() => {
    setModeState('cash');
    setDigitalMethod('gcash');
    setDpMethod('cash');
    setCashText('');
    setSplitText('');
  }, []);

  const draft: PaymentDraft = {
    mode,
    digitalMethod,
    dpMethod,
    cashReceived: Number(cashText) || 0,
    splitAmount: Number(splitText) || 0,
  };

  const error = paymentError(draft, grandTotal);
  return {
    mode,
    digitalMethod,
    dpMethod,
    cashText,
    splitText,
    setMode,
    setDigitalMethod,
    setDpMethod,
    setCashText,
    setSplitText,
    reset,
    paymentMethod: paymentLabel(mode),
    tenders: buildTenders(draft, grandTotal),
    amountReceived: amountReceivedFor(draft, grandTotal),
    changeGiven: changeGivenFor(draft, grandTotal),
    error,
    isValid: error === null,
  };
}
