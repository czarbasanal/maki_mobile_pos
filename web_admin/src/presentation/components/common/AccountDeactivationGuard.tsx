// Watches the signed-in user's OWN users/{uid} doc for the whole signed-in
// session (this component lives in AdminShell, which is only mounted while
// signed in). Mid-session deactivation → blocking modal + 10s countdown →
// sign-out. Doc deleted (exists == false) or the stream erroring with
// permission-denied → same modal, immediate sign-out. Normal sign-out
// unmounts the shell, which tears the subscription + timer down without
// ever showing the modal.
//
// Ordering guard (mirrors the mobile twin, lib/presentation/providers/
// account_deactivation_provider.dart `_signedOutSession`): correctness must
// not depend on the relative ordering of the auth-state transition and the
// doc-subscription's own events. A trailing doc-gone/permission-denied event
// can arrive on an already-superseded subscription closure *after* a normal
// sign-out (elsewhere, e.g. the Sidebar "Sign out" button) has already
// flipped the auth store — the Firestore listener's token invalidates as a
// side effect of that sign-out and can report permission-denied slightly
// after the fact. `signedOutSessionRef` is a ref (not local closure state)
// so every callback — including ones captured by a subscription instance
// that has already been superseded — reads the *current* value, not a
// snapshot taken when the callback was created.
//
// Idempotent-signOut guard (latitude — see task-8-report.md): react-router's
// `useNavigate()` is NOT identity-stable across a location change (its
// memoization deps include the current pathname) — calling
// `navigate(RoutePaths.login)` from inside `signOut()` would otherwise hand
// the "countdown → sign-out" effect below a *new* `navigate` reference on the
// next render, re-running the effect (resetting the visible countdown and
// re-invoking `signOut()`) purely as an artifact of the navigation it just
// made. Kept out of that effect's dependency array via refs for that reason;
// `didSignOutRef` additionally makes the sign-out call itself idempotent as
// defense-in-depth (mirrors the mobile twin's own `_signedOut` bool guard).

import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthRepo, useUserRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';

const COUNTDOWN_SECONDS = 10;

export function AccountDeactivationGuard() {
  const userRepo = useUserRepo();
  const authRepo = useAuthRepo();
  const navigate = useNavigate();
  const uid = useAuthStore((s) => s.user?.id ?? null);

  // null → all clear; countdown:true → deactivated (10s), false → doc gone.
  const [modal, setModal] = useState<null | { countdown: boolean }>(null);
  const [secondsLeft, setSecondsLeft] = useState(COUNTDOWN_SECONDS);

  // Set true whenever we're not in an active signed-in session (no uid, or
  // the session just ended) — see the ordering-guard note above.
  const signedOutSessionRef = useRef(false);
  // Makes the sign-out call idempotent — see the file-header note above.
  const didSignOutRef = useRef(false);
  // Always-latest refs so the countdown/sign-out effect below doesn't need
  // `authRepo`/`navigate` in its dependency array — see the file-header note.
  const authRepoRef = useRef(authRepo);
  authRepoRef.current = authRepo;
  const navigateRef = useRef(navigate);
  navigateRef.current = navigate;

  // Own-doc subscription, alive for the whole signed-in session.
  useEffect(() => {
    if (!uid) {
      signedOutSessionRef.current = true;
      return;
    }
    signedOutSessionRef.current = false;
    let fired = false; // must not double-fire on repeated snapshots
    const unsubscribe = userRepo.watchOne(
      uid,
      (user) => {
        if (fired || signedOutSessionRef.current) return;
        if (user === null) {
          fired = true;
          setModal({ countdown: false });
        } else if (!user.isActive) {
          fired = true;
          setModal({ countdown: true });
        }
      },
      (error) => {
        if (fired || signedOutSessionRef.current) return;
        if (error.code === 'permission-denied') {
          fired = true;
          setModal({ countdown: false });
        }
      },
    );
    return () => {
      // Set before unsubscribe(): any trailing event this subscription
      // fires from here on (including one already in flight) must be a
      // no-op, regardless of exactly when it lands relative to teardown.
      signedOutSessionRef.current = true;
      unsubscribe();
      setModal(null);
      setSecondsLeft(COUNTDOWN_SECONDS);
    };
  }, [uid, userRepo]);

  // Countdown → sign-out (or immediate sign-out for the doc-gone variant).
  // Deliberately depends on `modal` only — see the file-header note on why
  // `authRepo`/`navigate` are read via refs instead.
  useEffect(() => {
    if (!modal) return;
    const signOut = async () => {
      if (didSignOutRef.current) return;
      didSignOutRef.current = true;
      await authRepoRef.current.signOut().catch(() => {});
      navigateRef.current(RoutePaths.login, { replace: true });
    };
    if (!modal.countdown) {
      void signOut();
      return;
    }
    setSecondsLeft(COUNTDOWN_SECONDS);
    const interval = setInterval(() => {
      setSecondsLeft((s) => {
        if (s <= 1) {
          clearInterval(interval);
          void signOut();
          return 0;
        }
        return s - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [modal]);

  if (!modal) return null;

  return (
    <Dialog
      open
      onClose={() => {}}
      dismissable={false}
      title="Account deactivated"
      description="Your account has been deactivated by an administrator. You will be signed out."
    >
      <p className="text-bodySmall font-semibold text-light-text-secondary">
        {modal.countdown ? `Signing out in ${secondsLeft}s…` : 'Signing out…'}
      </p>
    </Dialog>
  );
}
