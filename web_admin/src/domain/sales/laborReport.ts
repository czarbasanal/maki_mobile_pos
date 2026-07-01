// Mirror of lib/core/utils/labor_report.dart. Aggregates labor (service)
// revenue by mechanic over a set of sales. Labor has zero cost, so labor
// revenue == labor profit. Voided and parts-only sales are excluded; service
// sales with no mechanic collapse into an "Unassigned" bucket.

import { type Sale, saleIsVoided, saleLaborRevenue } from '../entities';

export interface LaborByMechanic {
  /** Mechanic id, or null when the service sale carried no mechanic. */
  mechanicId: string | null;
  /** Display name — "Unassigned" when mechanicId is null. */
  mechanicName: string;
  laborTotal: number;
  jobCount: number;
}

export interface LaborReport {
  totalLabor: number;
  serviceSaleCount: number;
  /** Per-mechanic breakdown, sorted by laborTotal desc (ties by name asc). */
  byMechanic: LaborByMechanic[];
}

const UNASSIGNED_KEY = '__unassigned__';
const UNASSIGNED_NAME = 'Unassigned';

export function summarizeLabor(sales: Sale[]): LaborReport {
  const buckets = new Map<string, LaborByMechanic>();
  let totalLabor = 0;
  let serviceSaleCount = 0;

  for (const s of sales) {
    if (saleIsVoided(s)) continue;
    const labor = saleLaborRevenue(s);
    if (labor <= 0) continue;

    totalLabor += labor;
    serviceSaleCount++;

    const key = s.mechanicId ?? UNASSIGNED_KEY;
    const bucket = buckets.get(key) ?? {
      mechanicId: s.mechanicId ?? null,
      mechanicName: s.mechanicName ?? UNASSIGNED_NAME,
      laborTotal: 0,
      jobCount: 0,
    };
    bucket.laborTotal += labor;
    bucket.jobCount += 1;
    buckets.set(key, bucket);
  }

  const byMechanic = [...buckets.values()].sort((a, b) => {
    const byTotal = b.laborTotal - a.laborTotal;
    if (byTotal !== 0) return byTotal;
    return a.mechanicName.toLowerCase().localeCompare(b.mechanicName.toLowerCase());
  });

  return { totalLabor, serviceSaleCount, byMechanic };
}
