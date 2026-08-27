import { shopDayInt, shopOffsetMinutes } from '@/domain/time/shopTime';

/**
 * Shop business day as yyyymmdd — must match mobile's businessDayInt and the
 * rules' phDay(). Defaults to the configured shop offset (Asia/Manila +8
 * until an admin changes it in settings).
 */
export function phDayInt(now: Date = new Date(), offsetMinutes = shopOffsetMinutes()): number {
  return shopDayInt(now, offsetMinutes);
}
