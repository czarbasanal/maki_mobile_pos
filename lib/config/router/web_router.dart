import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/app_routes.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Router used by the web admin app.
///
/// Web is admin-only: any authenticated non-admin is bounced to /access-denied
/// after login. Otherwise the route table is identical to mobile (admin sees
/// every screen) and per-route permission gating still flows through
/// [RouteGuards.canAccess] as a defence-in-depth check.
final webRouterProvider = Provider<GoRouter>((ref) {
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
      final isAccessDenied = path == '/access-denied';

      if (!isLoggedIn && !isPublicRoute) return RoutePaths.login;

      if (isLoggedIn && user.role != UserRole.admin) {
        return isAccessDenied ? null : '/access-denied';
      }

      if (isLoggedIn && isLoginRoute) return RoutePaths.dashboard;
      if (isLoggedIn && !isPublicRoute && !RouteGuards.canAccess(path, user)) {
        return RoutePaths.dashboard;
      }
      return null;
    },
    errorBuilder: buildRouterErrorScreen,
    routes: appRoutes(),
  );
});
