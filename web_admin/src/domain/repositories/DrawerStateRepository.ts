import type { DrawerState } from '../entities/DrawerState';

export interface DrawerStateRepository {
  watch(onChange: (state: DrawerState) => void, onError?: (error: Error) => void): () => void;
}
