# Forgot Password screen — mobile + web

**Date:** 2026-07-23
**Status:** Approved

## Problem

Both surfaces can already send the Firebase password-reset email, but neither has a
dedicated UI for it:

- **Mobile** (`login_screen.dart` `_handleForgotPassword`): reuses whatever is typed in
  the *login* email field — nags "enter your email address first" when empty, then a
  confirm dialog, then sends.
- **Web** (`LoginPage.tsx`): `resetMode` flips an inline `ResetConfirm` panel that also
  reuses the login field's email; no input of its own.

Wanted: clicking "Forgot password?" shows a dedicated forgot-password screen with its
own email input, from which the Firebase reset link is sent. Same UX on both surfaces.

## Shared behavior

- "Forgot password?" on the login screen navigates to a dedicated screen/page.
- The screen has its own email input, **prefilled** with whatever was typed into the
  login email field (may be empty).
- Send button: validate email format → call the existing repo
  `sendPasswordResetEmail(email)` → in-place success state:
  "Reset email sent to *x* — check your inbox" + a "Back to login" action.
- No confirm dialog anywhere in the new flow.
- Errors keep today's mapping (`_mapFirebaseAuthException` on mobile,
  `friendlyAuthMessage` on web) and are shown on the screen.
- **No repo/data-layer change on either surface.** No Firebase console/template change.
- Explicitly out of scope: email-enumeration masking — a failed send for an unknown
  email surfaces the mapped error, as today (internal shop tool).

## Mobile (Flutter)

| Piece | Change |
|---|---|
| `lib/presentation/shared/screens/auth/forgot_password_screen.dart` | **New** `ForgotPasswordScreen({String? initialEmail})` — styled like the login screen (same header/card idioms, Lucide icons, `Validators.email`, `runWithWaiting` while sending). Success flips the body to the sent-state with "Back to login" (`context.pop()`). |
| `lib/config/router/route_names.dart` | `RouteNames.forgotPassword = 'forgotPassword'` (camelCase, matching `accessDenied`), `RoutePaths.forgotPassword = '/forgot-password'`. |
| `lib/config/router/app_routes.dart` | `authRoutes()` gains a `GoRoute` for it; prefill email passed via `state.extra as String?`. |
| `lib/config/router/route_guards.dart` | Add `/forgot-password` to `publicRoutes` (else the guard bounces unauthenticated users to `/login`). |
| `lib/presentation/shared/screens/auth/login_screen.dart` | `_handleForgotPassword` shrinks to `context.pushNamed(RouteNames.forgotPassword, extra: <typed email>)`. Empty-email nag, confirm dialog, and inline send are deleted. |

## Web (React)

| Piece | Change |
|---|---|
| `web_admin/src/presentation/features/auth/ForgotPasswordPage.tsx` | **New** — sibling of `LoginPage` inside `AuthLayout`. Email prefill via router `location.state?.email`. Uses the existing `useSendPasswordReset` hook untouched. Success state in place + `Link` back to `/login`; error via the existing error-banner idiom. |
| `web_admin/src/presentation/router/routePaths.ts` | `forgotPassword: '/forgot-password'`. |
| `web_admin/src/presentation/router/routes.tsx` | Mount under the `AuthLayout` group next to login. |
| `web_admin/src/presentation/router/routeGuards.ts` | Add to the **`publicRoutes` set** (the known 3-edit routing gotcha; here it's publicRoutes, not protectedRoutes). |
| `web_admin/src/presentation/features/auth/LoginPage.tsx` | Delete `resetMode` / `resetSuccess` / `ResetConfirm` / `onSendReset` (~40 lines). "Forgot password?" becomes `navigate(RoutePaths.forgotPassword, { state: { email } })`. |

Authed users visiting `/forgot-password` render it like `/login` today (AuthLayout pages
are not auth-redirected) — acceptable, unchanged behavior class.

## Tests (TDD)

- **Mobile** — widget tests for the new screen: renders with prefill; invalid/empty
  email blocks send with validation message; valid email calls
  `sendPasswordResetEmail` (mocked) and shows the success state; failure shows the
  mapped error. Guard test: `/forgot-password` is public. Login-screen test updated:
  tapping "Forgot password?" navigates with the typed email.
- **Web** — vitest: page renders with `location.state` prefill; invalid email blocked;
  valid send (mocked repo) → success state; error → banner. `routeGuards` test:
  `/forgot-password` in `publicRoutes`. LoginPage tests updated for the removed inline
  reset mode.
- Follow existing test-file locations/conventions on each surface.

## Verification

- Mobile: `flutter test`, `flutter analyze`.
- Web: `npm run typecheck`, `npm run test` (from `web_admin/`).
- Manual smoke: both surfaces — prefill carries over, email arrives, success + error paths.
