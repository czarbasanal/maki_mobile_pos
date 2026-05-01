// Mirror of lib/data/models/cost_code_model.dart. Stored at
// settings/cost_code_mapping (a single document; not a collection).

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { CostCode } from '@/domain/entities';
import { defaultCostCode } from '@/domain/entities';
import { toDate } from './timestamps';

export const costCodeConverter: FirestoreDataConverter<CostCode> = {
  toFirestore(cc) {
    return {
      digitToLetter: cc.digitToLetter,
      doubleZeroCode: cc.doubleZeroCode,
      tripleZeroCode: cc.tripleZeroCode,
      updatedBy: cc.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): CostCode {
    const d = snapshot.data();
    const raw = (d.digitToLetter ?? {}) as Record<string, unknown>;
    const digitToLetter: Record<string, string> = {};
    for (const [k, v] of Object.entries(raw)) digitToLetter[k] = String(v);

    if (Object.keys(digitToLetter).length === 0) {
      return { ...defaultCostCode };
    }

    return {
      digitToLetter,
      doubleZeroCode: d.doubleZeroCode ?? 'SC',
      tripleZeroCode: d.tripleZeroCode ?? 'SCS',
      updatedAt: toDate(d.updatedAt),
      updatedBy: d.updatedBy ?? null,
    };
  },
};
