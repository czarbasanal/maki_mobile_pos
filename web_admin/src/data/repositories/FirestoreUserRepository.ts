// Firestore implementation of UserRepository. Read methods mirror
// lib/data/repositories/user_repository_impl.dart. The CREATE path uses a
// **secondary Firebase Auth instance** so creating a user doesn't sign the
// admin out of the primary session — the Flutter version explicitly accepts
// that admin-logout behaviour, but the React side can do better with a
// trivial second-app workaround.

import { initializeApp, getApp, deleteApp, type FirebaseApp } from 'firebase/app';
import {
  createUserWithEmailAndPassword,
  getAuth,
  signOut,
} from 'firebase/auth';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import type { User } from '@/domain/entities';
import type { UserRole } from '@/domain/enums';
import type {
  UserCreateInput,
  UserListOptions,
  UserRepository,
  UserUpdateInput,
} from '@/domain/repositories/UserRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { firebaseApp } from '@/infrastructure/firebase/firebaseApp';
import { userConverter } from '@/data/converters/userConverter';

const SECONDARY_APP_NAME = 'maki-admin-create-user';

// Lazy-init a secondary FirebaseApp the first time a create runs. Reuse it
// across calls — initializeApp twice with the same name throws.
function getSecondaryApp(): FirebaseApp {
  try {
    return getApp(SECONDARY_APP_NAME);
  } catch {
    return initializeApp(firebaseApp.options, SECONDARY_APP_NAME);
  }
}

export class FirestoreUserRepository implements UserRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.users).withConverter(userConverter);
  }

  async getById(id: string): Promise<User | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.users, id).withConverter(userConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  async getByEmail(email: string): Promise<User | null> {
    const snap = await getDocs(
      query(this.col(), where('email', '==', email.trim()), limit(1)),
    );
    return snap.empty ? null : snap.docs[0].data();
  }

  async list({ includeInactive = false }: UserListOptions = {}): Promise<User[]> {
    const constraints = [orderBy('displayName')];
    if (!includeInactive) constraints.push(where('isActive', '==', true) as never);
    const snap = await getDocs(query(this.col(), ...(constraints as never[])));
    return snap.docs.map((d) => d.data());
  }

  async listByRole(role: UserRole): Promise<User[]> {
    const snap = await getDocs(
      query(
        this.col(),
        where('role', '==', role),
        where('isActive', '==', true),
        orderBy('displayName'),
      ),
    );
    return snap.docs.map((d) => d.data());
  }

  watchOne(id: string, callback: (user: User | null) => void): Unsubscribe {
    return onSnapshot(
      doc(this.db, FirestoreCollections.users, id).withConverter(userConverter),
      (snap) => callback(snap.exists() ? snap.data() : null),
    );
  }

  watchAll(
    callback: (users: User[]) => void,
    { includeInactive = false }: UserListOptions = {},
  ): Unsubscribe {
    const constraints = [orderBy('displayName')];
    if (!includeInactive) constraints.push(where('isActive', '==', true) as never);
    return onSnapshot(query(this.col(), ...(constraints as never[])), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  async emailExists(email: string): Promise<boolean> {
    return (await this.getByEmail(email)) !== null;
  }

  async create(input: UserCreateInput, actorId: string): Promise<User> {
    if (await this.emailExists(input.email)) {
      throw new Error('A user with this email already exists');
    }

    // Create the auth user on a secondary app so the primary (admin) session
    // is preserved. The secondary Auth signs in as the new user as a side
    // effect of createUserWithEmailAndPassword; we sign it back out before
    // returning.
    const secondary = getSecondaryApp();
    const secondaryAuth = getAuth(secondary);
    let uid: string;
    try {
      const cred = await createUserWithEmailAndPassword(
        secondaryAuth,
        input.email.trim(),
        input.password,
      );
      uid = cred.user.uid;
    } finally {
      await signOut(secondaryAuth).catch(() => {});
    }

    const ref = doc(this.db, FirestoreCollections.users, uid);
    await setDoc(ref, {
      email: input.email.trim(),
      displayName: input.displayName.trim(),
      role: input.role,
      isActive: true,
      phoneNumber: input.phoneNumber ?? null,
      photoUrl: null,
      createdBy: actorId,
      updatedBy: null,
      createdAt: serverTimestamp(),
    });

    const created = await this.getById(uid);
    if (!created) throw new Error('Failed to load created user');
    return created;
  }

  async update(input: UserUpdateInput, actorId: string): Promise<User> {
    const patch: Record<string, unknown> = {
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
    };
    if (input.displayName !== undefined) patch.displayName = input.displayName.trim();
    if (input.role !== undefined) patch.role = input.role;
    if (input.phoneNumber !== undefined) patch.phoneNumber = input.phoneNumber ?? null;
    if (input.isActive !== undefined) patch.isActive = input.isActive;

    await updateDoc(doc(this.db, FirestoreCollections.users, input.id), patch);
    const updated = await this.getById(input.id);
    if (!updated) throw new Error('User not found after update');
    return updated;
  }

  async deactivate(id: string, actorId: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.users, id), {
      isActive: false,
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
    });
  }

  async reactivate(id: string, actorId: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.users, id), {
      isActive: true,
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
    });
  }

  async recordLogin(id: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.users, id), {
      lastLoginAt: serverTimestamp(),
    });
  }
}

// Exposed for tests / explicit teardown — not used in production.
export async function disposeSecondaryUserApp(): Promise<void> {
  try {
    await deleteApp(getApp(SECONDARY_APP_NAME));
  } catch {
    // No-op if the secondary app was never initialized.
  }
}
