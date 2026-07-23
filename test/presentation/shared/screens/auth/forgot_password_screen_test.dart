import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/app_routes.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/errors/errors.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/screens/auth/forgot_password_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/screens/auth/login_screen.dart';
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

  testWidgets('has no app-bar back icon; Login button returns to login',
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
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
