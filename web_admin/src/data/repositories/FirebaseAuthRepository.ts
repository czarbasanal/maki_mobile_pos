// Implementation of AuthRepository against Firebase Auth + Firestore. Loads
// the user profile from `users/{uid}` after sign-in so the React app gets the
// same UserEntity the Flutter app sees. Mirrors lib/data/repositories/auth_repository_impl.dart.

import {
  EmailAuthProvider,
  reauthenticateWithCredential,
  sendPasswordResetEmail as fbSendPasswordResetEmail,
  signInWithEmailAndPassword as fbSignIn,
  signOut as fbSignOut,
  updatePassword as fbUpdatePassword,
  type Auth,
  type User as FirebaseUser,
} from 'firebase/auth';
import { doc, getDoc, type Firestore } from 'firebase/firestore';
import type {
  AuthRepository,
  AuthStateListener,
  Unsubscribe,
} from '@/domain/repositories/AuthRepository';
import type { User } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { userConverter } from '@/data/converters/userConverter';

export class AuthError extends Error {
  constructor(
    message: string,
    public readonly code?: string,
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

export class FirebaseAuthRepository implements AuthRepository {
  constructor(
    private readonly auth: Auth,
    private readonly db: Firestore,
  ) {}

  get isSignedIn(): boolean {
    return this.auth.currentUser != null;
  }

  get currentUserId(): string | null {
    return this.auth.currentUser?.uid ?? null;
  }

  async signInWithEmailAndPassword(email: string, password: string): Promise<User> {
    try {
      const cred = await fbSignIn(this.auth, email, password);
      const user = await this.loadProfile(cred.user.uid);
      if (!user) {
        await fbSignOut(this.auth);
        throw new AuthError('No user profile found for this account.', 'no-profile');
      }
      if (!user.isActive) {
        await fbSignOut(this.auth);
        throw new AuthError('This account has been deactivated.', 'inactive');
      }
      return user;
    } catch (e) {
      if (e instanceof AuthError) throw e;
      const fb = e as { code?: string; message?: string };
      throw new AuthError(fb.message ?? 'Sign-in failed', fb.code);
    }
  }

  async signOut(): Promise<void> {
    await fbSignOut(this.auth);
  }

  async getCurrentUser(): Promise<User | null> {
    const fbUser = this.auth.currentUser;
    if (!fbUser) return null;
    return this.loadProfile(fbUser.uid);
  }

  onAuthStateChanged(listener: AuthStateListener): Unsubscribe {
    return this.auth.onAuthStateChanged(async (fbUser: FirebaseUser | null) => {
      if (!fbUser) {
        listener(null);
        return;
      }
      try {
        const user = await this.loadProfile(fbUser.uid);
        listener(user);
      } catch {
        listener(null);
      }
    });
  }

  async verifyPassword(password: string): Promise<boolean> {
    const fbUser = this.auth.currentUser;
    if (!fbUser?.email) return false;
    try {
      const credential = EmailAuthProvider.credential(fbUser.email, password);
      await reauthenticateWithCredential(fbUser, credential);
      return true;
    } catch {
      return false;
    }
  }

  async sendPasswordResetEmail(email: string): Promise<void> {
    await fbSendPasswordResetEmail(this.auth, email);
  }

  async updatePassword(currentPassword: string, newPassword: string): Promise<void> {
    const fbUser = this.auth.currentUser;
    if (!fbUser?.email) throw new AuthError('No signed-in user.', 'no-user');
    const credential = EmailAuthProvider.credential(fbUser.email, currentPassword);
    await reauthenticateWithCredential(fbUser, credential);
    await fbUpdatePassword(fbUser, newPassword);
  }

  private async loadProfile(uid: string): Promise<User | null> {
    const ref = doc(this.db, FirestoreCollections.users, uid).withConverter(userConverter);
    const snap = await getDoc(ref);
    return snap.exists() ? snap.data() : null;
  }
}
