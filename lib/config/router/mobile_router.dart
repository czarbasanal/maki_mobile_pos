import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/app_routes.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Router used by the mobile app (admin / staff / cashier).
///
/// Role gating is delegated to [RouteGuards.canAccess], which decides what a
/// role may REACH. What a role can SEE is built per screen — the dashboard
/// composes its own tiles and Settings its own rows, each checking permissions
/// inline. There is deliberately no central menu registry: one existed, drove
/// no UI, and let supplier management look reachable for months while nothing
/// rendered a way in.
final mobileRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublicRoute = RouteGuards.isPublicRoute(path);

      final user = authState.whenOrNull(data: (user) => user);
      if (authState.isLoading) return null;

      final isLoggedIn = user != null;
      final isLoginRoute = path == RoutePaths.login;
      final isAccessDenied = path == RoutePaths.accessDenied;

      if (!isLoggedIn && !isPublicRoute) return RoutePaths.login;
      if (isLoggedIn && isLoginRoute) return RoutePaths.dashboard;
      // 403s land on /access-denied so the user gets visible feedback —
      // silent redirects to / made deep links look broken to cashier/staff.
      if (isLoggedIn &&
          !isPublicRoute &&
          !isAccessDenied &&
          !RouteGuards.canAccess(path, user)) {
        return RoutePaths.accessDenied;
      }
      return null;
    },
    errorBuilder: buildRouterErrorScreen,
    routes: [
      ...authRoutes(),
      ...featureRoutes(),
    ],
  );
});
