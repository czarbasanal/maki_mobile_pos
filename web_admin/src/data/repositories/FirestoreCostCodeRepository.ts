// Firestore implementation of CostCodeRepository. The mapping lives at
// settings/cost_code_mapping as a single document — get + watch return the
// default mapping when the doc doesn't exist yet.

import {
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  setDoc,
  type Firestore,
} from 'firebase/firestore';
import type { CostCodeRepository } from '@/domain/repositories/CostCodeRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { defaultCostCode, type CostCode } from '@/domain/entities';
import {
  FirestoreCollections,
  SettingsDocs,
} from '@/infrastructure/firebase/collections';
import { costCodeConverter } from '@/data/converters/costCodeConverter';

export class FirestoreCostCodeRepository implements CostCodeRepository {
  constructor(private readonly db: Firestore) {}

  private docRef() {
    return doc(
      this.db,
      FirestoreCollections.settings,
      SettingsDocs.costCodeMapping,
    ).withConverter(costCodeConverter);
  }

  async get(): Promise<CostCode> {
    const snap = await getDoc(this.docRef());
    return snap.exists() ? snap.data() : { ...defaultCostCode };
  }

  watch(callback: (cc: CostCode) => void): Unsubscribe {
    return onSnapshot(this.docRef(), (snap) => {
      callback(snap.exists() ? snap.data() : { ...defaultCostCode });
    });
  }

  async update(input: Omit<CostCode, 'updatedAt' | 'updatedBy'>, actorId: string): Promise<void> {
    // setDoc with merge:true preserves the doc on first write while still
    // updating the fields — mirrors the Flutter `set(toMap(forUpdate: true))`.
    const ref = doc(this.db, FirestoreCollections.settings, SettingsDocs.costCodeMapping);
    await setDoc(
      ref,
      {
        digitToLetter: input.digitToLetter,
        doubleZeroCode: input.doubleZeroCode,
        tripleZeroCode: input.tripleZeroCode,
        updatedBy: actorId,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  }
}
