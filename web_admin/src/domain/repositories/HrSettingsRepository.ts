import type { HrSettings } from '@/domain/hr/types';

export interface HrSettingsRepository {
  get(): Promise<HrSettings>;
  save(settings: HrSettings): Promise<void>;
}
