// Mirror of lib/domain/repositories/user_repository.dart. Implementations
// arrive in phase 4 (`/users` migration).

import type { User } from '../entities';
import type { UserRole } from '../enums';
import type { Unsubscribe } from './AuthRepository';

export interface UserCreateInput {
  email: string;
  displayName: string;
  role: UserRole;
  phoneNumber?: string | null;
  password: string;
}

export interface UserUpdateInput {
  displayName?: string;
  role?: UserRole;
  phoneNumber?: string | null;
  isActive?: boolean;
}

export interface UserRepository {
  getById(id: string): Promise<User | null>;
  list(): Promise<User[]>;
  watchAll(callback: (users: User[]) => void): Unsubscribe;
  create(input: UserCreateInput, actorId: string): Promise<User>;
  update(id: string, input: UserUpdateInput, actorId: string): Promise<void>;
  deactivate(id: string, actorId: string): Promise<void>;
  recordLogin(id: string): Promise<void>;
}
