import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/app_routes.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Router used by the mobile app (admin / staff / cashier).
///
/// Role gating is delegated to [RouteGuards.canAccess]; the dashboard's menu
/// is also driven by [RouteGuards.getMenuItems] so each role sees only the
/// tabs it can use.
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

      if (!isLoggedIn && !isPublicRoute) return RoutePaths.login;
      if (isLoggedIn && isLoginRoute) return RoutePaths.dashboard;
      if (isLoggedIn && !isPublicRoute && !RouteGuards.canAccess(path, user)) {
        return RoutePaths.dashboard;
      }
      return null;
    },
    errorBuilder: buildRouterErrorScreen,
    routes: [
      ...authRoutes(),
      ...featureRoutes(Surface.mobile),
    ],
  );
});
