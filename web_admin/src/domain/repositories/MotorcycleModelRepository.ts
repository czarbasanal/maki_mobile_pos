import type { MotorcycleModel } from '../entities/MotorcycleModel';
import type { Unsubscribe } from './AuthRepository';

export interface MotorcycleModelRepository {
  /** Live ACTIVE models, name-sorted — the picker source. */
  watchActive(onData: (models: MotorcycleModel[]) => void, onError?: (e: Error) => void): Unsubscribe;
  /** Case-insensitive lookup by dedup key; null when none matches. */
  findByNormalizedKey(key: string): Promise<MotorcycleModel | null>;
  create(name: string, actorId: string): Promise<MotorcycleModel>;
  /** Best-effort reactivation — firestore rules deny cashiers the flip. */
  setActive(id: string, active: boolean, actorId: string): Promise<void>;
}
