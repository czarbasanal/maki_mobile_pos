import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  DeleteAccountError,
  runDeleteUserAccount,
  type DeleteAccountDeps,
  type DeleteAccountInput,
  type DeleteAccountResult,
} from './deleteUserAccount';

initializeApp();

const deps: DeleteAccountDeps = {
  async getUserDoc(uid) {
    const snap = await getFirestore().collection('users').doc(uid).get();
    if (!snap.exists) return null;
    const d = snap.data() ?? {};
    return { role: String(d.role ?? ''), isActive: d.isActive === true };
  },
  async deleteUserDoc(uid) {
    await getFirestore().collection('users').doc(uid).delete();
  },
  async getUserByEmail(email) {
    try {
      const u = await getAuth().getUserByEmail(email);
      return { uid: u.uid };
    } catch (e) {
      if ((e as { code?: string }).code === 'auth/user-not-found') return null;
      throw e;
    }
  },
  async deleteAuthUser(uid) {
    try {
      await getAuth().deleteUser(uid);
      return 'deleted';
    } catch (e) {
      if ((e as { code?: string }).code === 'auth/user-not-found') return 'not-found';
      throw e;
    }
  },
};

/** Admin-only: remove a user's Auth login and profile (deactivate-first, never yourself). */
export const deleteUserAccount = onCall<DeleteAccountInput, Promise<DeleteAccountResult>>(
  { region: 'asia-southeast1' },
  async (request) => {
    try {
      return await runDeleteUserAccount(deps, request.auth?.uid ?? null, request.data);
    } catch (e) {
      if (e instanceof DeleteAccountError) throw new HttpsError(e.code, e.message);
      throw e;
    }
  },
);
