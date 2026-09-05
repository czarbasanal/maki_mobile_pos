// A clock that ticks on an interval so derived ages keep ageing while the
// tab sits open (void-requests guide §3: "age must re-derive on a timer").
import { useEffect, useState } from 'react';

export function useNow(intervalMs = 60_000): Date {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}
