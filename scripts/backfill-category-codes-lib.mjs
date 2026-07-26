/**
 * Plans code assignments for categories that don't have one.
 * Assigns codes in 4-digit format (0001, 0002, etc.) starting from max existing code + 1.
 *
 * @param {Array<{id, name, createdAt, code?}>} categories - All categories from product_categories
 * @returns {Array<{id, code, name}>} - Assignments for uncoded categories, sorted by createdAt then id
 */
export function planAssignments(categories) {
  // Filter to categories without a code
  const uncoded = categories.filter(cat => !cat.code);

  if (uncoded.length === 0) {
    return [];
  }

  // Find the max existing code
  const existingCodes = categories
    .filter(cat => cat.code)
    .map(cat => parseInt(cat.code, 10))
    .filter(code => !isNaN(code));

  const maxExisting = existingCodes.length > 0 ? Math.max(...existingCodes) : 0;

  // Sort by createdAt (ascending), then by id
  uncoded.sort((a, b) => {
    const aTime = a.createdAt?.seconds ?? a.createdAt ?? 0;
    const bTime = b.createdAt?.seconds ?? b.createdAt ?? 0;
    if (aTime !== bTime) {
      return aTime - bTime;
    }
    return a.id.localeCompare(b.id);
  });

  // Assign codes starting from maxExisting + 1
  const assignments = uncoded.map((cat, index) => {
    const codeNum = maxExisting + 1 + index;
    const code = String(codeNum).padStart(4, '0');
    return {
      id: cat.id,
      code,
      name: cat.name,
    };
  });

  return assignments;
}

/**
 * Calculates the next counter value after making assignments.
 *
 * @param {Array<{id, code, name}>} assignments - Assignments from planAssignments
 * @param {number} existingMax - The highest code number that already exists (0 if none)
 * @returns {number} - The next counter value to use
 */
export function counterAfter(assignments, existingMax) {
  if (assignments.length === 0) {
    return existingMax + 1;
  }

  // Get the last assigned code (they're in order)
  const lastCode = assignments[assignments.length - 1].code;
  const lastCodeNum = parseInt(lastCode, 10);

  // Counter should be the max of the last assigned code and existing max, plus 1
  return Math.max(lastCodeNum, existingMax) + 1;
}
