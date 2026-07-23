# Forgot Password Screen (Mobile + Web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the login-field-piggybacking "Forgot password?" flows with a dedicated forgot-password screen (own email input → Firebase reset email) on both mobile and web.

**Architecture:** No data-layer change on either surface — mobile keeps calling `authActionsProvider.sendPasswordResetEmail` (→ `AuthRepositoryImpl` → Firebase), web keeps the `useSendPasswordReset` hook (→ `FirebaseAuthRepository`). We add one new screen/page per surface, register a `/forgot-password` route in each router's public set, and shrink the login screens' forgot handlers to a navigation carrying the typed email as prefill.

**Tech Stack:** Flutter + Riverpod + go_router + mocktail (mobile); React + react-router + react-hook-form/zod + TanStack Query + Vitest/Testing Library (web).

**Spec:** `docs/superpowers/specs/2026-07-23-forgot-password-screen-design.md`

## Global Constraints

- Branch: `feat/forgot-password-screen` (already created; spec committed).
- Mobile commands run at repo root: `flutter test`, `flutter analyze`. Web commands run inside `web_admin/`: `npm run typecheck`, `npm run test`.
- Success copy (both surfaces): "Reset email sent to *email* — check your inbox." Button copy: "Send reset link"; back action: "Back to login".
- Error copy fallback (mobile generic catch): `Failed to send reset email. Please try again.`
- No confirm dialog anywhere in the new flow. No email-enumeration masking. No Firebase console/template changes.
- Mobile route: `RoutePaths.forgotPassword = '/forgot-password'`, `RouteNames.forgotPassword = 'forgotPassword'`. Web route: `RoutePaths.forgotPassword = '/forgot-password'`.

---

### Task 1: Mobile — route constants + public-route guard

**Files:**
- Modify: `lib/config/router/route_names.dart` (RouteNames auth section ~line 9; RoutePaths auth section ~line 191)
- Modify: `lib/config/router/route_guards.dart:14-16` (`publicRoutes`)
- Test: `test/config/router/route_guards_test.dart`

**Interfaces:**
- Produces: `RouteNames.forgotPassword` (`'forgotPassword'`), `RoutePaths.forgotPassword` (`'/forgot-password'`) — Tasks 2–3 use these; `RouteGuards.publicRoutes` contains `'/forgot-password'`.

- [ ] **Step 1: Write the failing tests** — in `test/config/router/route_guards_test.dart`, extend the existing `RouteGuards.isPublicRoute` group and the unauthenticated `canAccess` group:

```dart
    test('forgot-password is public', () {
      expect(RouteGuards.isPublicRoute(RoutePaths.forgotPassword), true);
    });
```

and inside `group('RouteGuards.canAccess — unauthenticated', ...)`:

```dart
    test('null user can access /forgot-password', () {
      expect(RouteGuards.canAccess(RoutePaths.forgotPassword, null), true);
    });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/config/router/route_guards_test.dart`
Expected: FAIL — `RoutePaths.forgotPassword` is not defined (compile error).

- [ ] **Step 3: Implement.** In `lib/config/router/route_names.dart`, RouteNames auth section (after `login`):

```dart
  /// Forgot-password screen route — requests a Firebase reset email.
  static const String forgotPassword = 'forgotPassword';
```

RoutePaths auth section (after `login`):

```dart
  static const String forgotPassword = '/forgot-password';
```

In `lib/config/router/route_guards.dart`:

```dart
  static const Set<String> publicRoutes = {
    '/login',
    '/forgot-password',
  };
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/config/router/route_guards_test.dart`
Expected: PASS (all tests in file).

- [ ] **Step 5: Commit**

```bash
git add lib/config/router/route_names.dart lib/config/router/route_guards.dart test/config/router/route_guards_test.dart
git commit -m "feat(mobile): /forgot-password route constants + public guard"
```

---

### Task 2: Mobile — ForgotPasswordScreen widget

**Files:**
- Create: `lib/presentation/shared/screens/auth/forgot_password_screen.dart`
- Test: `test/presentation/shared/screens/auth/forgot_password_screen_test.dart` (new directory)

**Interfaces:**
- Consumes: `authActionsProvider` (`Provider<AuthNotifier>`, `lib/presentation/providers/auth_provider.dart:172`) — calls `sendPasswordResetEmail(String)`; `Validators.email`; `context.runWithWaiting` (extension in `app_waiting_dialog.dart`, exported via `common_widgets.dart`); `AppTextField`, `AppButton` (same barrel); `AuthException` from `core/errors/errors.dart`.
- Produces: `ForgotPasswordScreen({super.key, this.initialEmail})` — Task 3's route builder passes `initialEmail` from `state.extra as String?`.

- [ ] **Step 1: Write the failing widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/errors.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/screens/auth/forgot_password_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthNotifier extends Mock implements AuthNotifier {}

Widget _harness(AuthNotifier auth, {String? initialEmail}) {
  return ProviderScope(
    overrides: [authActionsProvider.overrideWithValue(auth)],
    child: MaterialApp(home: ForgotPasswordScreen(initialEmail: initialEmail)),
  );
}

void main() {
  late _MockAuthNotifier auth;

  setUp(() {
    auth = _MockAuthNotifier();
  });

  testWidgets('prefills the email from initialEmail', (tester) async {
    await tester.pumpWidget(_harness(auth, initialEmail: 'shop@maki.ph'));
    expect(find.text('shop@maki.ph'), findsOneWidget);
  });

  testWidgets('empty email blocks send with validation message',
      (tester) async {
    await tester.pumpWidget(_harness(auth));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    verifyNever(() => auth.sendPasswordResetEmail(any()));
  });

  testWidgets('invalid email blocks send with validation message',
      (tester) async {
    await tester.pumpWidget(_harness(auth, initialEmail: 'not-an-email'));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address'), findsOneWidget);
    verifyNever(() => auth.sendPasswordResetEmail(any()));
  });

  testWidgets('valid email sends and shows the success state', (tester) async {
    when(() => auth.sendPasswordResetEmail(any())).thenAnswer((_) async {});
    await tester.pumpWidget(_harness(auth, initialEmail: 'shop@maki.ph'));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    verify(() => auth.sendPasswordResetEmail('shop@maki.ph')).called(1);
    expect(find.textContaining('Reset email sent to'), findsOneWidget);
    expect(find.text('Back to login'), findsOneWidget);
  });

  testWidgets('AuthException surfaces its message inline', (tester) async {
    when(() => auth.sendPasswordResetEmail(any())).thenThrow(
      const AuthException(message: 'No account found for that email'),
    );
    await tester.pumpWidget(_harness(auth, initialEmail: 'shop@maki.ph'));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('No account found for that email'), findsOneWidget);
    expect(find.textContaining('Reset email sent to'), findsNothing);
  });
}
```

Note: check `AuthException`'s actual constructor in `lib/core/errors/exceptions.dart` — if `message` is positional or the class isn't const, adjust the throw line accordingly (`AuthException(message: ...)` matches how `auth_provider.dart` constructs it).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/presentation/shared/screens/auth/forgot_password_screen_test.dart`
Expected: FAIL — `forgot_password_screen.dart` does not exist (compile error).

- [ ] **Step 3: Implement the screen** — mirror `login_screen.dart` idioms (ConstrainedBox 360, `AppTextField`, `AppButton`, inline error box):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/errors/errors.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/utils.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Requests a Firebase password-reset email for the entered address.
///
/// Pushed from the login screen; [initialEmail] carries over whatever was
/// typed into the login form's email field (may be null/empty).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  String? _errorMessage;

  /// Non-null once the reset email has been sent — flips the body to the
  /// success state.
  String? _sentTo;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    try {
      await context.runWithWaiting(
        () => ref.read(authActionsProvider).sendPasswordResetEmail(email),
        message: 'Sending…',
      );
      if (mounted) setState(() => _sentTo = email);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Failed to send reset email. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _sentTo == null ? _buildForm() : _buildSent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],
          AppTextField(
            controller: _emailController,
            labelText: 'Email',
            prefixIcon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            onSubmitted: (_) => _handleSend(),
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Send reset link',
            onPressed: _handleSend,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.mailCheck, size: 48, color: scheme.primary),
        const SizedBox(height: 22),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Reset email sent to $_sentTo — check your inbox.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        AppButton(
          text: 'Back to login',
          onPressed: () => context.pop(),
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(LucideIcons.lockKeyholeOpen, size: 48, color: scheme.primary),
        const SizedBox(height: 22),
        Text(
          'Reset password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email and we'll send you a reset link.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // Same inline error idiom as login_screen.dart's _buildErrorMessage.
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.errorDark,
                fontSize: 13,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
```

Adjustment latitude: if `LucideIcons.lockKeyholeOpen` / `LucideIcons.mailCheck` don't exist in `lucide_icons_flutter 3.1.14+2`, pick the closest existing names (e.g. `LucideIcons.keyRound`, `LucideIcons.mailCheck` → `LucideIcons.checkCircle2`); if `context.pop()` needs go_router's import it's already imported.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/presentation/shared/screens/auth/forgot_password_screen_test.dart`
Expected: PASS (5 tests). If `pumpAndSettle` times out on the waiting dialog's spinner, replace the post-tap `pumpAndSettle()` with `await tester.pump(); await tester.pump(const Duration(milliseconds: 400)); await tester.pump(const Duration(milliseconds: 400));`.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/screens/auth/forgot_password_screen.dart test/presentation/shared/screens/auth/forgot_password_screen_test.dart
git commit -m "feat(mobile): ForgotPasswordScreen with own email input + success state"
```

---

### Task 3: Mobile — register the route and rewire the login screen

**Files:**
- Modify: `lib/config/router/app_routes.dart:151-162` (`authRoutes()`)
- Modify: `lib/presentation/shared/screens/auth/login_screen.dart:62-103` (`_handleForgotPassword`)
- Test: `test/presentation/shared/screens/auth/forgot_password_screen_test.dart` (add a navigation test)

**Interfaces:**
- Consumes: `ForgotPasswordScreen(initialEmail:)` from Task 2; `RouteNames.forgotPassword` / `RoutePaths.forgotPassword` from Task 1; `authRoutes()` from `app_routes.dart`.
- Produces: `/forgot-password` GoRoute whose builder reads `state.extra as String?` as the prefill email.

- [ ] **Step 1: Write the failing navigation test** — append to `forgot_password_screen_test.dart` (add imports `package:go_router/go_router.dart`, `package:maki_mobile_pos/config/router/app_routes.dart`, `package:maki_mobile_pos/config/router/route_names.dart`):

```dart
  testWidgets('login "Forgot password?" opens the screen with the typed email',
      (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.login,
      routes: authRoutes(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authActionsProvider.overrideWithValue(auth)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'shop@maki.ph');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('shop@maki.ph'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/presentation/shared/screens/auth/forgot_password_screen_test.dart`
Expected: FAIL — tapping "Forgot password?" opens the old confirm-dialog flow (no route registered), `findsOneWidget` on `ForgotPasswordScreen` fails.

- [ ] **Step 3: Implement.** In `app_routes.dart` `authRoutes()`, after the login GoRoute (import `forgot_password_screen.dart` at top alongside the `login_screen.dart` import):

```dart
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (context, state) =>
            ForgotPasswordScreen(initialEmail: state.extra as String?),
      ),
```

In `login_screen.dart`, replace the whole `_handleForgotPassword` method (lines 62–103) with:

```dart
  void _handleForgotPassword() {
    context.pushNamed(
      RouteNames.forgotPassword,
      extra: _emailController.text.trim(),
    );
  }
```

Then remove imports that became unused (`flutter analyze` will name them — likely `navigation_extensions.dart`; keep `errors.dart`, `utils.dart`, `route_names.dart`, `go_router` which are still used by `_handleLogin`/validators).

- [ ] **Step 4: Run tests + analyzer**

Run: `flutter test test/presentation/shared/screens/auth/ test/config/router/route_guards_test.dart && flutter analyze`
Expected: PASS, analyzer clean (no unused imports).

- [ ] **Step 5: Commit**

```bash
git add lib/config/router/app_routes.dart lib/presentation/shared/screens/auth/login_screen.dart test/presentation/shared/screens/auth/forgot_password_screen_test.dart
git commit -m "feat(mobile): route /forgot-password + login rewire to dedicated screen"
```

---

### Task 4: Web — route path + public guard

**Files:**
- Modify: `web_admin/src/presentation/router/routePaths.ts:6-7`
- Modify: `web_admin/src/presentation/router/routeGuards.ts:9`
- Test: `web_admin/src/presentation/router/routeGuards.test.ts`

**Interfaces:**
- Produces: `RoutePaths.forgotPassword` (`'/forgot-password'`); `canAccess('/forgot-password', anyone)` → `true`. Tasks 5–6 use `RoutePaths.forgotPassword`.

- [ ] **Step 1: Write the failing tests** — append to `routeGuards.test.ts` (the `admin`/`cashier` fixtures already exist at top of file):

```ts
describe('canAccess — forgot-password', () => {
  it('is public: reachable signed out and by any role', () => {
    expect(canAccess(RoutePaths.forgotPassword, null)).toBe(true);
    expect(canAccess(RoutePaths.forgotPassword, admin)).toBe(true);
    expect(canAccess(RoutePaths.forgotPassword, cashier)).toBe(true);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run (from `web_admin/`): `npm run test -- routeGuards`
Expected: FAIL — `forgotPassword` missing from `RoutePaths` (type error) or `canAccess` returns false.

- [ ] **Step 3: Implement.** `routePaths.ts` (auth block):

```ts
  login: '/login',
  forgotPassword: '/forgot-password',
  accessDenied: '/access-denied',
```

`routeGuards.ts:9`:

```ts
const publicRoutes: ReadonlySet<string> = new Set([RoutePaths.login, RoutePaths.forgotPassword]);
```

- [ ] **Step 4: Run to verify pass**

Run: `npm run test -- routeGuards` then `npm run typecheck`
Expected: PASS / clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/router/routePaths.ts web_admin/src/presentation/router/routeGuards.ts web_admin/src/presentation/router/routeGuards.test.ts
git commit -m "feat(web): /forgot-password path + public-route guard"
```

---

### Task 5: Web — shared auth UI bits + ForgotPasswordPage + mount

**Files:**
- Create: `web_admin/src/presentation/features/auth/authUi.tsx` (move `inputCls`, `Field`, `ErrorBanner` out of `LoginPage.tsx` verbatim, exported)
- Create: `web_admin/src/presentation/features/auth/ForgotPasswordPage.tsx`
- Modify: `web_admin/src/presentation/features/auth/LoginPage.tsx` (import the three from `./authUi`, delete the local copies at lines 191–217 and 241–251)
- Modify: `web_admin/src/presentation/router/routes.tsx:55-60` (mount under `AuthLayout`)
- Test: `web_admin/src/presentation/features/auth/ForgotPasswordPage.test.tsx`

**Interfaces:**
- Consumes: `useSendPasswordReset` (unchanged), `RoutePaths.forgotPassword` (Task 4), `Spinner` from `LoadingView`, `DiProvider`/`Container` test harness idiom (as in `CheckoutPage.test.tsx`).
- Produces: `ForgotPasswordPage` (no props; prefill via `location.state.email`); `authUi.tsx` exporting `inputCls(hasError: boolean): string`, `Field({label, error?, input})`, `ErrorBanner({message, onDismiss})` — Task 6's LoginPage cleanup relies on these staying export-compatible.

- [ ] **Step 1: Create `authUi.tsx`** — cut `inputCls`, `Field`, `ErrorBanner` from `LoginPage.tsx` **unchanged** except adding `export` and the needed imports:

```tsx
// Shared visual bits for the AuthLayout pages (login, forgot-password).

import { ExclamationCircleIcon, XMarkIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

export function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
    // Thicker outline on focus, no glow: drop the soft ring shadow and use a
    // real CSS outline (no layout shift) layered just outside the border.
    'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
    hasError ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
  );
}

export function Field({
  label,
  error,
  input,
}: {
  label: string;
  error?: string;
  input: React.ReactNode;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-error">{error}</span> : null}
    </label>
  );
}

export function ErrorBanner({ message, onDismiss }: { message: string; onDismiss: () => void }) {
  return (
    <div className="flex items-start gap-tk-sm rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-error-dark">
      <ExclamationCircleIcon className="mt-[2px] h-4 w-4 shrink-0 text-error" />
      <p className="flex-1 text-[13px]">{message}</p>
      <button type="button" onClick={onDismiss} aria-label="Dismiss">
        <XMarkIcon className="h-4 w-4 text-error" />
      </button>
    </div>
  );
}
```

In `LoginPage.tsx`: delete the local `inputCls`, `Field`, `ErrorBanner` definitions and add `import { ErrorBanner, Field, inputCls } from './authUi';` (drop `ExclamationCircleIcon`/`XMarkIcon` from the heroicons import if now unused there — `XMarkIcon` is still used by `SuccessBanner` until Task 6 removes it).

- [ ] **Step 2: Write the failing page tests** — `ForgotPasswordPage.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ForgotPasswordPage } from './ForgotPasswordPage';

function harness(
  authRepo: Partial<Container['authRepo']>,
  state?: { email?: string },
) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  return render(
    <DiProvider override={{ authRepo: authRepo as Container['authRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[{ pathname: '/forgot-password', state }]}>
          <Routes>
            <Route path="/forgot-password" element={<ForgotPasswordPage />} />
            <Route path="/login" element={<div>LOGIN PAGE</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ForgotPasswordPage', () => {
  it('prefills the email from router state', () => {
    harness({ sendPasswordResetEmail: vi.fn() }, { email: 'shop@maki.ph' });
    expect(screen.getByLabelText(/email/i)).toHaveValue('shop@maki.ph');
  });

  it('blocks an empty email without calling the repo', async () => {
    const send = vi.fn();
    harness({ sendPasswordResetEmail: send });
    await userEvent.click(screen.getByRole('button', { name: /send reset link/i }));
    expect(await screen.findByText('Email is required')).toBeInTheDocument();
    expect(send).not.toHaveBeenCalled();
  });

  it('sends and shows the success state', async () => {
    const send = vi.fn().mockResolvedValue(undefined);
    harness({ sendPasswordResetEmail: send }, { email: 'shop@maki.ph' });
    await userEvent.click(screen.getByRole('button', { name: /send reset link/i }));
    await waitFor(() => expect(send).toHaveBeenCalledWith('shop@maki.ph'));
    expect(await screen.findByText(/reset email sent to/i)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /back to login/i })).toBeInTheDocument();
  });

  it('surfaces a send failure in the error banner', async () => {
    const send = vi.fn().mockRejectedValue(new Error('No account found for that email'));
    harness({ sendPasswordResetEmail: send }, { email: 'shop@maki.ph' });
    await userEvent.click(screen.getByRole('button', { name: /send reset link/i }));
    expect(
      await screen.findByText('No account found for that email'),
    ).toBeInTheDocument();
    expect(screen.queryByText(/reset email sent to/i)).not.toBeInTheDocument();
  });
});
```

Note: `getByLabelText` works because `Field` wraps the input in a `<label>`.

- [ ] **Step 3: Run to verify failure**

Run: `npm run test -- ForgotPasswordPage`
Expected: FAIL — module `./ForgotPasswordPage` not found.

- [ ] **Step 4: Implement `ForgotPasswordPage.tsx`:**

```tsx
// /forgot-password — request a Firebase password-reset email. Sibling of
// LoginPage inside AuthLayout; the login form's typed email arrives as
// router state for prefill.

import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { CheckCircleIcon } from '@heroicons/react/24/outline';
import { useSendPasswordReset } from '@/presentation/hooks/useSendPasswordReset';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorBanner, Field, inputCls } from './authUi';

const resetSchema = z.object({
  email: z.string().trim().min(1, 'Email is required').email('Invalid email address'),
});

type ResetValues = z.infer<typeof resetSchema>;

export function ForgotPasswordPage() {
  const location = useLocation();
  const prefill = (location.state as { email?: string } | null)?.email ?? '';
  const [sentTo, setSentTo] = useState<string | null>(null);
  const sendReset = useSendPasswordReset();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ResetValues>({
    resolver: zodResolver(resetSchema),
    defaultValues: { email: prefill },
  });

  useEffect(() => {
    document.title = 'Reset password · MAKI POS Admin';
  }, []);

  const onSubmit = async (values: ResetValues) => {
    sendReset.reset();
    const email = values.email.trim();
    try {
      await sendReset.mutateAsync(email);
      setSentTo(email);
    } catch {
      // Error surfaces via sendReset.error below.
    }
  };

  if (sentTo) {
    return (
      <div className="space-y-tk-xl">
        <div className="flex flex-col items-center text-center">
          <CheckCircleIcon className="h-10 w-10 text-success" />
          <h1 className="mt-tk-md text-bodyLarge font-semibold tracking-tight text-light-text">
            Check your inbox
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Reset email sent to <span className="font-semibold">{sentTo}</span> — check
            your inbox.
          </p>
        </div>
        <div className="flex justify-center">
          <Link
            to={RoutePaths.login}
            className="text-bodySmall text-light-text-secondary underline-offset-2 hover:text-light-text hover:underline"
          >
            Back to login
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-tk-xl">
      <div className="flex flex-col items-center text-center">
        <h1 className="text-bodyLarge font-semibold tracking-tight text-light-text">
          Reset password
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Enter your email and we&apos;ll send you a reset link.
        </p>
      </div>

      {sendReset.error ? (
        <ErrorBanner
          message={sendReset.error.message}
          onDismiss={() => sendReset.reset()}
        />
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-md" noValidate>
        <Field
          label="Email"
          error={errors.email?.message}
          input={
            <input
              type="email"
              autoComplete="email"
              autoFocus
              {...register('email')}
              className={inputCls(!!errors.email)}
            />
          }
        />

        <button
          type="submit"
          disabled={sendReset.isPending}
          className="flex w-full items-center justify-center gap-tk-sm rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background transition-colors hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
        >
          {sendReset.isPending ? <Spinner className="h-4 w-4" /> : null}
          {sendReset.isPending ? 'Sending…' : 'Send reset link'}
        </button>

        <div className="flex justify-center pt-tk-xs">
          <Link
            to={RoutePaths.login}
            className="text-bodySmall text-light-text-secondary underline-offset-2 hover:text-light-text hover:underline"
          >
            Back to login
          </Link>
        </div>
      </form>
    </div>
  );
}
```

Mount in `routes.tsx` (AuthLayout children, after login; add the import next to `LoginPage`'s):

```tsx
import { ForgotPasswordPage } from '@/presentation/features/auth/ForgotPasswordPage';
```

```tsx
      children: [
        { path: RoutePaths.login, element: <LoginPage /> },
        { path: RoutePaths.forgotPassword, element: <ForgotPasswordPage /> },
        { path: RoutePaths.accessDenied, element: <AccessDeniedPage /> },
      ],
```

- [ ] **Step 5: Run to verify pass**

Run: `npm run test -- ForgotPasswordPage` then `npm run typecheck`
Expected: PASS (4 tests) / clean. (LoginPage still compiles — it now imports the shared bits.)

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/features/auth/authUi.tsx web_admin/src/presentation/features/auth/ForgotPasswordPage.tsx web_admin/src/presentation/features/auth/ForgotPasswordPage.test.tsx web_admin/src/presentation/features/auth/LoginPage.tsx web_admin/src/presentation/router/routes.tsx
git commit -m "feat(web): /forgot-password page with own email input + success state"
```

---

### Task 6: Web — LoginPage sheds the inline reset flow

**Files:**
- Modify: `web_admin/src/presentation/features/auth/LoginPage.tsx`

**Interfaces:**
- Consumes: `RoutePaths.forgotPassword` (Task 4); `navigate` + `getValues` already in LoginPage.
- Produces: LoginPage's "Forgot password?" navigates to `/forgot-password` with `{ state: { email } }`. No component API change.

- [ ] **Step 1: Rewire.** In `LoginPage.tsx`:

Delete: `resetMode`/`setResetMode` and `resetSuccess`/`setResetSuccess` state (lines 38–39), `const sendReset = useSendPasswordReset();` (line 42) and its import (line 19), the whole `onSendReset` function (lines 80–98), the `setResetSuccess(null)` line inside `onSubmit` (line 66), the `resetSuccess` success-banner JSX (lines 108–110), the whole `ResetConfirm` component (lines 265–307), the whole `SuccessBanner` component (lines 253–263), and `CheckCircleIcon` from the heroicons import.

Change `banner` (line 101) to:

```tsx
  const banner = signIn.error?.message ?? null;
```

Replace the forgot-password JSX block (lines 163–183) with:

```tsx
        <div className="flex justify-center pt-tk-xs">
          <button
            type="button"
            onClick={() =>
              navigate(RoutePaths.forgotPassword, {
                state: { email: getValues('email').trim() },
              })
            }
            className="text-bodySmall text-light-text-secondary underline-offset-2 hover:text-light-text hover:underline"
          >
            Forgot password?
          </button>
        </div>
```

- [ ] **Step 2: Verify**

Run: `npm run typecheck && npm run test`
Expected: clean typecheck (unused-import errors would surface here — `tsc -b` with `noUnusedLocals`), full web suite PASS (196+ tests, plus the new ones).

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/auth/LoginPage.tsx
git commit -m "feat(web): login Forgot password? navigates to /forgot-password"
```

---

### Task 7: Full verification (both surfaces)

- [ ] **Step 1: Mobile full suite + analyzer**

Run (repo root): `flutter analyze && flutter test`
Expected: analyzer clean; all tests pass (1141 baseline + the new ones).

- [ ] **Step 2: Web full suite + build**

Run (web_admin/): `npm run typecheck && npm run test && npm run build`
Expected: all clean/green.

- [ ] **Step 3: Commit any stragglers; then hand off**

After this task: run `/code-review` on the branch diff, fix findings, then `/verify` (web dev-server smoke of /login → /forgot-password; mobile is user-smoked on device). Merge via the finishing-a-development-branch flow. Deployment note: web goes live only after `firebase deploy --only hosting`; mobile ships in the next APK build+install.
