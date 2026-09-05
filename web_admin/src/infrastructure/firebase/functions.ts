// Callable Cloud Functions (functions/src/index.ts). Same region as Firestore.
import { getFunctions, httpsCallable } from 'firebase/functions';
import { firebaseApp } from './firebaseApp';

const functions = getFunctions(firebaseApp, 'asia-southeast1');

export interface DeleteAccountInput {
  uid?: string;
  email?: string;
}
export interface DeleteAccountResult {
  uid: string;
  authDeleted: boolean;
  docDeleted: boolean;
}

/** Removes a user's Auth login AND profile (admin-only, deactivate-first, never yourself);
 *  by `email` it clears an orphaned login. Rethrows the function's own message. */
export async function deleteUserAccount(input: DeleteAccountInput): Promise<DeleteAccountResult> {
  try {
    const res = await httpsCallable<DeleteAccountInput, DeleteAccountResult>(functions, 'deleteUserAccount')(input);
    return res.data;
  } catch (e) {
    throw new Error((e as { message?: string }).message ?? 'Could not delete the account');
  }
}
