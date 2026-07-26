/**
 * Plans code assignments for categories that don't have one.
 * Assigns codes in 4-digit format (0001, 0002, etc.), starting from the
 * highest known-used code + 1 — where "known-used" is the max of: existing
 * category `code`s, existing `category_codes` registry doc ids, and
 * (counterNext ?? 1) - 1. The registry state matters because an in-app
 * category hard-delete removes the category doc (and its `code`) but NOT the
 * `category_codes/{code}` registry doc or the `_counter`, which stays live so
 * runtime category creation keeps working. Flooring on category codes alone
 * would let a re-run reassign a deleted category's code, overwriting its
 * still-live registry doc and regressing `_counter` — which then bricks
 * runtime category creation (rules deny tx.set on an existing registry doc).
 *
 * @param {Array<{id, name, createdAt, code?}>} categories - All categories from product_categories
 * @param {{registryCodes?: string[], counterNext?: number|null}} [opts]
 *   - registryCodes: every `category_codes` doc id EXCLUDING `_counter`
 *   - counterNext: the current `_counter.next` value (or null if no counter doc yet)
 * @returns {Array<{id, code, name}>} - Assignments for uncoded categories, sorted by createdAt then id
 */
export function planAssignments(categories, { registryCodes = [], counterNext = null } = {}) {
  // Filter to categories without a code
  const uncoded = categories.filter(cat => !cat.code);

  if (uncoded.length === 0) {
    return [];
  }

  // Find the max existing code across every source of "already used".
  const existingCodes = categories
    .filter(cat => cat.code)
    .map(cat => parseInt(cat.code, 10))
    .filter(code => !isNaN(code));
  const maxCategoryCode = existingCodes.length > 0 ? Math.max(...existingCodes) : 0;

  const registryCodeNums = registryCodes
    .map(code => parseInt(code, 10))
    .filter(code => !isNaN(code));
  const maxRegistryCode = registryCodeNums.length > 0 ? Math.max(...registryCodeNums) : 0;

  const counterFloor = counterNext != null ? counterNext - 1 : 0;

  const floor = Math.max(maxCategoryCode, maxRegistryCode, counterFloor);

  // Sort by createdAt (ascending), then by id
  uncoded.sort((a, b) => {
    const aTime = a.createdAt?.seconds ?? a.createdAt ?? 0;
    const bTime = b.createdAt?.seconds ?? b.createdAt ?? 0;
    if (aTime !== bTime) {
      return aTime - bTime;
    }
    return a.id.localeCompare(b.id);
  });

  // Assign codes starting from floor + 1, skipping any code a registry doc
  // already claims (defensive: covers a stale/lagging counter too).
  const registryCodeSet = new Set(registryCodes);
  const assignments = [];
  let next = floor + 1;
  for (const cat of uncoded) {
    while (registryCodeSet.has(String(next).padStart(4, '0'))) {
      next += 1;
    }
    const code = String(next).padStart(4, '0');
    assignments.push({ id: cat.id, code, name: cat.name });
    next += 1;
  }

  return assignments;
}

/**
 * Calculates the next counter value after making assignments.
 *
 * @param {Array<{id, code, name}>} assignments - Assignments from planAssignments
 * @param {number} existingMax - The highest code number that already exists (0 if none)
 * @param {number|null} [counterNext] - The current `_counter.next` value (or null if no counter doc yet)
 * @returns {number} - The next counter value to use — never lower than counterNext
 */
export function counterAfter(assignments, existingMax, counterNext = null) {
  const counterUsedFloor = counterNext != null ? counterNext - 1 : 0;
  const floor = Math.max(existingMax, counterUsedFloor);

  if (assignments.length === 0) {
    return floor + 1;
  }

  // Get the last assigned code (they're in order)
  const lastCode = assignments[assignments.length - 1].code;
  const lastCodeNum = parseInt(lastCode, 10);

  return Math.max(lastCodeNum, floor) + 1;
}
