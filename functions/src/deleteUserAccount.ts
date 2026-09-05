// Delete a user account for good: the Firebase Auth login AND the users/{uid}
// profile. Only the Admin SDK can remove another person's credential, which
// is why this lives here and not in the web client. Pure logic with injected
// deps so it is unit-tested with fakes; index.ts wires the real SDKs.
//
// Guards mirror the client (userGuards.ts) and firestore.rules: an ACTIVE
// ADMIN caller, never yourself, and deactivate-first. Passing `email`
// instead of `uid` clears an orphaned login — a credential whose profile
// doc was removed by an earlier in-app delete.

export type DeleteAccountCode =
  | 'unauthenticated'
  | 'permission-denied'
  | 'invalid-argument'
  | 'failed-precondition'
  | 'not-found';

export class DeleteAccountError extends Error {
  constructor(
    public readonly code: DeleteAccountCode,
    message: string,
  ) {
    super(message);
    this.name = 'DeleteAccountError';
  }
}

export interface UserDoc {
  role: string;
  isActive: boolean;
}

export interface DeleteAccountDeps {
  getUserDoc(uid: string): Promise<UserDoc | null>;
  deleteUserDoc(uid: string): Promise<void>;
  /** null when no Auth user carries that email. */
  getUserByEmail(email: string): Promise<{ uid: string } | null>;
  /** 'not-found' when the credential is already gone — treated as done. */
  deleteAuthUser(uid: string): Promise<'deleted' | 'not-found'>;
}

export interface DeleteAccountInput {
  uid?: string;
  email?: string;
}

export interface DeleteAccountResult {
  uid: string;
  authDeleted: boolean;
  docDeleted: boolean;
}

function parseInput(input: unknown): DeleteAccountInput {
  const o = (input ?? {}) as Record<string, unknown>;
  const uid = typeof o.uid === 'string' && o.uid.trim() ? o.uid.trim() : undefined;
  const email = typeof o.email === 'string' && o.email.trim() ? o.email.trim().toLowerCase() : undefined;
  if (!uid && !email) throw new DeleteAccountError('invalid-argument', 'Pass a uid or an email.');
  return { uid, email };
}

export async function runDeleteUserAccount(
  deps: DeleteAccountDeps,
  callerUid: string | null,
  rawInput: unknown,
): Promise<DeleteAccountResult> {
  if (!callerUid) throw new DeleteAccountError('unauthenticated', 'Sign in to delete accounts.');
  const caller = await deps.getUserDoc(callerUid);
  if (!caller || caller.role !== 'admin' || !caller.isActive) {
    throw new DeleteAccountError('permission-denied', 'Only an active admin can delete accounts.');
  }

  const input = parseInput(rawInput);
  let uid = input.uid;
  if (!uid && input.email) {
    const found = await deps.getUserByEmail(input.email);
    if (!found) throw new DeleteAccountError('not-found', 'No login exists for that email.');
    uid = found.uid;
  }
  if (!uid) throw new DeleteAccountError('invalid-argument', 'Pass a uid or an email.');
  if (uid === callerUid) throw new DeleteAccountError('failed-precondition', 'You cannot delete yourself.');

  const target = await deps.getUserDoc(uid);
  if (target && target.isActive) {
    throw new DeleteAccountError('failed-precondition', 'Deactivate this user before deleting them.');
  }

  // Auth first: if this fails the profile is still there to retry from; if
  // the doc delete fails afterwards, a retry finds the login already gone
  // (tolerated) and finishes the job.
  const auth = await deps.deleteAuthUser(uid);
  let docDeleted = false;
  if (target) {
    await deps.deleteUserDoc(uid);
    docDeleted = true;
  }
  return { uid, authDeleted: auth === 'deleted', docDeleted };
}
