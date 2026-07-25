/**
 * Detects and plans a patch for the amountReceived bug in mobile cash sales.
 * Bug signature: paymentMethod === 'cash' && changeGiven > 0 && tenders && amountReceived === tenders.cash
 * Truth: amountReceived should be amountReceived + changeGiven
 *
 * @param {Object} doc - sale document
 * @returns {Object|null} - { amountReceived: newValue } if patch needed, null otherwise
 */
export function planPatch(doc) {
  const { paymentMethod, changeGiven, tenders, amountReceived } = doc;

  // Apply the guard: all conditions must be true
  if (paymentMethod === 'cash' && changeGiven > 0 && tenders && amountReceived === tenders.cash) {
    return { amountReceived: amountReceived + changeGiven };
  }

  return null;
}
