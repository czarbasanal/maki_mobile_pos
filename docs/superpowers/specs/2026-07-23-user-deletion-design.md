# User deletion (deactivate-first) + mid-session deactivation handling

**Date:** 2026-07-23
**Status:** Approved

## Problem

1. Admins can deactivate users but never remove them — the users list accretes
   ex-employees forever. There is no delete anywhere (no `deleteUser` in either
   surface's repository), even though `Permission.deleteUser` already exists on
   both surfaces (admin-only) and `firestore.rules` already has a users
   `allow delete` — one that is **too loose** (any admin can delete any user,
   including themselves, active or not).
2. Deactivation only takes effect at the **next sign-in**: both surfaces fetch
   the user profile once per Firebase-auth transition
   (`auth_repository_impl.dart` `authStateChanges`, web
   `FirebaseAuthRepository.onAuthStateChanged`). A deactivated user keeps a
   live session until restart; their writes fail rules with raw errors.

## Behavior

### Delete user (web admin + mobile admin)

- Admin-only (`Permission.deleteUser`, already assigned to admin on both
  surfaces). A user **must be deactivated first**: the delete action is only
  shown/enabled for `isActive == false` users. Self-delete impossible (an admin
  cannot deactivate themselves, and rules add an explicit uid check anyway).
- Delete removes the `users/{uid}` **Firestore doc** (client SDKs cannot remove
  another user's Firebase Auth credential). Confirm dialog before delete
  (destructive style), naming the user.
- **Web:** Users list row action (with deactivate/reactivate, same
  confirm-dialog pattern in `UsersListPage.tsx`), visible only on inactive
  rows.
- **Mobile:** delete action for inactive users in the users screen flow
  (mirroring the existing deactivate/reactivate placement; `runWithWaiting`
  "Deleting…", `showAppConfirmDialog` destructive).
- Historical records (sales, logs) keep denormalized uid/name strings — no
  cascade, no rewriting history.

### Rules tightening (production-affecting; deploy with user's go-ahead)

```
allow delete: if isAdmin() && isActiveUser()
  && request.auth.uid != userId
  && resource.data.isActive == false;
```

Enforces deactivate-first and no-self-delete server-side. Covered by the rules
test suite if one exists for users (extend it; else note in plan).

### Mid-session deactivation → warning modal + timed auto sign-out (both surfaces)

- New live snapshot listener on the signed-in user's **own** `users/{uid}` doc,
  active for the whole signed-in session, started at app root.
- On `isActive` flipping false: a **blocking, non-dismissable modal** — title
  "Account deactivated", body "Your account has been deactivated by an
  administrator. You will be signed out." — with a **10-second countdown**
  shown in the modal, then automatic sign-out (landing on login). Existing
  session-state reset (`sessionResetProvider` on mobile / auth listener on web)
  rides the sign-out as usual.
- On the doc being **deleted** mid-session (snapshot `exists == false`) or the
  stream erroring with permission-denied: same modal, but sign-out fires
  **immediately** (no countdown) — deletion implies prior deactivation, so this
  is the tail case.
- Rules already permit a user to read their own doc regardless of isActive
  (comment at `firestore.rules:46-48`), so the listener keeps working after
  deactivation — until deletion, which lands in the doc-gone path.
- **Mobile:** root-level Riverpod listener (same activation idiom as
  `sessionResetProvider` in `app_mobile.dart`), dialog via the root navigator
  key; countdown in the dialog; sign-out via `authActionsProvider.signOut()`
  (falls back to `FirebaseAuth.signOut` if the use-case path requires an
  actor). Must not double-fire if the stream emits repeatedly.
- **Web:** subscription started with the auth bootstrap
  (`useAuthBootstrap`/`authStore`), modal rendered from `AdminShell`; sign-out
  via `authRepo.signOut()` + navigate to login.
- Signing out **normally** while the watcher is alive must tear it down without
  showing the modal (watch for the auth transition, cancel listener + timer).

### Auth-credential cleanup script

- New `scripts/delete-auth-user.mjs` (firebase-admin, applicationDefault
  credentials, PROJECT_ID `maki-mobile-pos`, same conventions as the
  backfills): `node delete-auth-user.mjs <email-or-uid>` — looks up the auth
  account, ABORTS if a `users/{uid}` doc still exists (in-app delete first),
  prints what it found, requires `--apply` to actually delete the credential.

## Out of scope

- Cloud Functions / server-side cascade deletion.
- Any change to activity-log retention or historical records.
- Undo/restore for deleted users (re-create via Add User if needed).

## Tests

- Repos: delete method delegates correctly (both surfaces' existing repo-test
  idioms).
- Web: UsersListPage — delete action absent on active rows, present on
  inactive; confirm flow calls the hook; self row never shows delete. Modal
  component: renders countdown, fires sign-out at zero (fake timers), doc-gone
  → immediate sign-out.
- Mobile: widget/unit tests for the watcher provider (deactivation event →
  modal state; doc-gone → immediate sign-out; normal sign-out → no modal), and
  users-screen delete gating (inactive only).
- Rules: extend the users rules suite for the tightened delete (active target
  rejected, self rejected, inactive other-user accepted) if a rules test rig
  exists; otherwise document manual verification in the plan.

## Verification

- `flutter test` / `flutter analyze`; `npm run typecheck` / `npm run test` /
  `npm run build` (web_admin).
- Manual: deactivate a signed-in test user from the other surface → modal +
  countdown + sign-out observed on both surfaces; delete flow end-to-end;
  script dry-run + apply against a throwaway auth account.
- Deploy: hosting + **firestore rules (confirm with user first)**; mobile
  rides the next APK.
