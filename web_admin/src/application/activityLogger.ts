// Thin fire-and-forget wrapper over ActivityLogRepository.log(). Every web
// mutation site calls `logActivity(repo, {...})` right after its write
// succeeds — this never awaits the log, and any repo rejection (permission
// denial, offline, etc.) is swallowed here so a failed audit-log entry can
// never fail or slow down the mutation that triggered it.
//
// The acting user (id/name/role) is injected from the Zustand auth store
// rather than threaded through every call site — `useAuthStore.getState()`
// works outside React (mutationFn closures, plain functions), so this stays
// a plain function rather than a hook. If there's no signed-in user (should
// never happen at a mutation site, but defensively), logging is skipped.

import { useAuthStore } from '@/presentation/stores/authStore';
import type { ActivityLogRepository } from '@/domain/repositories/ActivityLogRepository';
import type { ActivityLog, ActivityType, User } from '@/domain/entities';

export interface LogActivityInput {
  type: ActivityType;
  action: string;
  details?: string | null;
  entityId?: string | null;
  entityType?: string | null;
  metadata?: Record<string, unknown> | null;
}

/**
 * Fire-and-forget: never returns a rejected promise, never throws.
 *
 * `build` is a thunk rather than a plain object because most call sites
 * compute `action`/`details`/`metadata` from a mutation's return value (e.g.
 * `sale.saleNumber`, `saleGrandTotal(sale)`) — fields a hand-rolled test
 * double can easily leave out. Evaluating that inside the try/catch means a
 * sparse fake (or any other unexpected-shape input) can never break the
 * mutation it's logging, on top of the repo-write itself already being
 * swallowed below.
 *
 * `actorOverride` lets a call site pin the acting user explicitly instead of
 * reading the store at call time — needed for sign-out, where the store is
 * cleared (by the same mutation's own signOut() call, via the
 * onAuthStateChanged bridge) before this can run.
 */
function buildEntry(user: User, input: LogActivityInput): Omit<ActivityLog, 'id' | 'createdAt'> {
  return {
    type: input.type,
    action: input.action,
    details: input.details ?? null,
    userId: user.id,
    userName: user.displayName,
    userRole: user.role,
    entityId: input.entityId ?? null,
    entityType: input.entityType ?? null,
    metadata: input.metadata ?? null,
    deviceInfo: null,
  };
}

export function logActivity(
  repo: ActivityLogRepository,
  build: () => LogActivityInput,
  actorOverride?: User,
): void {
  try {
    const user = actorOverride ?? useAuthStore.getState().user;
    if (!user) return;

    void repo.log(buildEntry(user, build())).catch(() => {
      // Swallowed — a failed audit-log write must never surface to the caller.
    });
  } catch {
    // Defensive: a throwing `build()` or a synchronously-throwing fake/repo
    // must not propagate either — see the file-level note above.
  }
}

/**
 * Awaited variant, same swallow-everything contract. For the rare site that
 * must confirm the write LANDED while the session is still valid — sign-out,
 * where a fire-and-forget entry queued after signOut() goes out with no auth
 * token, gets denied by the `user_logs` rules, and vanishes silently.
 */
export async function logActivityAndWait(
  repo: ActivityLogRepository,
  build: () => LogActivityInput,
  actorOverride?: User,
): Promise<void> {
  try {
    const user = actorOverride ?? useAuthStore.getState().user;
    if (!user) return;

    await repo.log(buildEntry(user, build()));
  } catch {
    // Same contract as logActivity: a failed audit-log write never
    // propagates to (or slows down more than one awaited write) the caller.
  }
}
