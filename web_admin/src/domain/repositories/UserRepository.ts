// Mirror of lib/domain/repositories/user_repository.dart.

import type { User } from '../entities';
import type { UserRole } from '../enums';
import type { Unsubscribe } from './AuthRepository';

export interface UserCreateInput {
  email: string;
  displayName: string;
  role: UserRole;
  password: string;
  phoneNumber?: string | null;
}

export interface UserUpdateInput {
  id: string;
  displayName?: string;
  role?: UserRole;
  phoneNumber?: string | null;
  isActive?: boolean;
}

export interface UserListOptions {
  includeInactive?: boolean;
}

export interface UserRepository {
  // Read
  getById(id: string): Promise<User | null>;
  getByEmail(email: string): Promise<User | null>;
  list(opts?: UserListOptions): Promise<User[]>;
  listByRole(role: UserRole): Promise<User[]>;
  watchOne(id: string, callback: (user: User | null) => void): Unsubscribe;
  watchAll(callback: (users: User[]) => void, opts?: UserListOptions): Unsubscribe;

  // Write
  create(input: UserCreateInput, actorId: string): Promise<User>;
  update(input: UserUpdateInput, actorId: string): Promise<User>;
  deactivate(id: string, actorId: string): Promise<void>;
  reactivate(id: string, actorId: string): Promise<void>;
  recordLogin(id: string): Promise<void>;

  // Utility
  emailExists(email: string): Promise<boolean>;
}
