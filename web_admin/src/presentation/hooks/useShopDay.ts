// The current SHOP (PHT) calendar day as a reactive value. Ticks over at
// shop midnight even in an idle tab — the web twin of mobile's
// business_day_provider midnight timer — so day-scoped subscriptions and
// the header re-window without a reload, on any device timezone.
import { useEffect, useState } from 'react';
import { shopDateKey } from '@/domain/time/shopTime';

const CHECK_MS = 30_000;

export function useShopDay(): string {
  const [day, setDay] = useState(() => shopDateKey(new Date()));
  useEffect(() => {
    const tick = () => {
      const next = shopDateKey(new Date());
      setDay((prev) => (prev === next ? prev : next));
    };
    const t = setInterval(tick, CHECK_MS);
    // A laptop waking from sleep should not wait for the next interval.
    window.addEventListener('focus', tick);
    return () => {
      clearInterval(t);
      window.removeEventListener('focus', tick);
    };
  }, []);
  return day;
}
