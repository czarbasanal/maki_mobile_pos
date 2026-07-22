// Firestore implementation of HrSettingsRepository. The settings live at
// settings/hr as a single document — get returns DEFAULT_HR_SETTINGS when the
// doc doesn't exist yet, mirroring FirestoreCostCodeRepository.

import { doc, getDoc, setDoc, type Firestore } from 'firebase/firestore';
import type { HrSettingsRepository } from '@/domain/repositories/HrSettingsRepository';
import { DEFAULT_HR_SETTINGS, type HrSettings } from '@/domain/hr/types';
import { FirestoreCollections, SettingsDocs } from '@/infrastructure/firebase/collections';

export class FirestoreHrSettingsRepository implements HrSettingsRepository {
  constructor(private readonly db: Firestore) {}

  private docRef() {
    return doc(this.db, FirestoreCollections.settings, SettingsDocs.hr);
  }

  async get(): Promise<HrSettings> {
    const snap = await getDoc(this.docRef());
    if (!snap.exists()) return { ...DEFAULT_HR_SETTINGS };
    const d = snap.data();
    return {
      weekStartDay: d.weekStartDay ?? DEFAULT_HR_SETTINGS.weekStartDay,
      regularHolidayPct: d.regularHolidayPct ?? DEFAULT_HR_SETTINGS.regularHolidayPct,
      specialHolidayPct: d.specialHolidayPct ?? DEFAULT_HR_SETTINGS.specialHolidayPct,
    };
  }

  async save(settings: HrSettings): Promise<void> {
    await setDoc(this.docRef(), {
      weekStartDay: settings.weekStartDay,
      regularHolidayPct: settings.regularHolidayPct,
      specialHolidayPct: settings.specialHolidayPct,
    });
  }
}
