import { useEffect, useState } from 'react';

/** The value, trailing-debounced. Suggestion dropdowns filter the whole
 *  catalog per keystroke — debouncing the query keeps typing smooth on the
 *  fast-entry screens (receiving, price-history lookup). */
export function useDebouncedValue<T>(value: T, delayMs = 200): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(t);
  }, [value, delayMs]);
  return debounced;
}
