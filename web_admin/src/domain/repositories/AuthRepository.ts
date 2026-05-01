// Mirror of lib/domain/repositories/auth_repository.dart.

import type { User } from '../entities';

export type AuthStateListener = (user: User | null) => void;
export type Unsubscribe = () => void;

export interface AuthRepository {
  signInWithEmailAndPassword(email: string, password: string): Promise<User>;
  signOut(): Promise<void>;
  getCurrentUser(): Promise<User | null>;
  onAuthStateChanged(listener: AuthStateListener): Unsubscribe;
  verifyPassword(password: string): Promise<boolean>;
  sendPasswordResetEmail(email: string): Promise<void>;
  updatePassword(currentPassword: string, newPassword: string): Promise<void>;
  readonly isSignedIn: boolean;
  readonly currentUserId: string | null;
}
