import { describe, expect, it, vi } from 'vitest';
import { DeleteAccountError, runDeleteUserAccount, type DeleteAccountDeps, type UserDoc } from './deleteUserAccount';

function fakeDeps(docs: Record<string, UserDoc>, authByEmail: Record<string, string> = {}) {
  const deleted: string[] = [];
  const authDeleted: string[] = [];
  const deps: DeleteAccountDeps = {
    getUserDoc: vi.fn(async (uid) => docs[uid] ?? null),
    deleteUserDoc: vi.fn(async (uid) => { deleted.push(uid); }),
    getUserByEmail: vi.fn(async (email) => (authByEmail[email] ? { uid: authByEmail[email] } : null)),
    deleteAuthUser: vi.fn(async (uid) => (uid.startsWith('gone-') ? 'not-found' : 'deleted')),
  };
  return { deps, deleted, authDeleted };
}

const ADMIN: UserDoc = { role: 'admin', isActive: true };
const CASHIER_OFF: UserDoc = { role: 'cashier', isActive: false };
const CASHIER_ON: UserDoc = { role: 'cashier', isActive: true };

describe('runDeleteUserAccount', () => {
  it('an active admin deletes a deactivated user: Auth first, then the profile', async () => {
    const { deps, deleted } = fakeDeps({ me: ADMIN, c1: CASHIER_OFF });
    const r = await runDeleteUserAccount(deps, 'me', { uid: 'c1' });
    expect(r).toEqual({ uid: 'c1', authDeleted: true, docDeleted: true });
    expect(deps.deleteAuthUser).toHaveBeenCalledWith('c1');
    expect(deleted).toEqual(['c1']);
  });

  it('refuses when signed out, or when the caller is not an active admin', async () => {
    const { deps } = fakeDeps({ me: ADMIN, s1: { role: 'staff', isActive: true }, off: { role: 'admin', isActive: false }, c1: CASHIER_OFF });
    await expect(runDeleteUserAccount(deps, null, { uid: 'c1' })).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(runDeleteUserAccount(deps, 's1', { uid: 'c1' })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(runDeleteUserAccount(deps, 'off', { uid: 'c1' })).rejects.toMatchObject({ code: 'permission-denied' });
    expect(deps.deleteAuthUser).not.toHaveBeenCalled();
  });

  it('never deletes yourself', async () => {
    const { deps } = fakeDeps({ me: ADMIN });
    await expect(runDeleteUserAccount(deps, 'me', { uid: 'me' })).rejects.toThrow('You cannot delete yourself.');
  });

  it('deactivate-first: an active target is refused before anything is touched', async () => {
    const { deps, deleted } = fakeDeps({ me: ADMIN, c1: CASHIER_ON });
    await expect(runDeleteUserAccount(deps, 'me', { uid: 'c1' })).rejects.toThrow('Deactivate this user before deleting them.');
    expect(deps.deleteAuthUser).not.toHaveBeenCalled();
    expect(deleted).toEqual([]);
  });

  it('by email clears an orphaned login whose profile is already gone', async () => {
    const { deps, deleted } = fakeDeps({ me: ADMIN }, { 'jeric@shop.test': 'orphan-1' });
    const r = await runDeleteUserAccount(deps, 'me', { email: 'Jeric@Shop.test ' });
    expect(r).toEqual({ uid: 'orphan-1', authDeleted: true, docDeleted: false });
    expect(deleted).toEqual([]);
  });

  it('by email with no such login is not-found; an already-gone credential is tolerated', async () => {
    const { deps } = fakeDeps({ me: ADMIN, 'gone-1': CASHIER_OFF });
    await expect(runDeleteUserAccount(deps, 'me', { email: 'nobody@shop.test' })).rejects.toMatchObject({ code: 'not-found' });
    const r = await runDeleteUserAccount(deps, 'me', { uid: 'gone-1' });
    expect(r).toEqual({ uid: 'gone-1', authDeleted: false, docDeleted: true });
  });

  it('rejects an empty input', async () => {
    const { deps } = fakeDeps({ me: ADMIN });
    await expect(runDeleteUserAccount(deps, 'me', {})).rejects.toBeInstanceOf(DeleteAccountError);
    await expect(runDeleteUserAccount(deps, 'me', { uid: '  ' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});
