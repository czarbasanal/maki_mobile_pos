import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/app_router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// The root widget of the POS application.
///
/// Configures:
/// - Theme (light/dark)
/// - Router (go_router)
/// - Localization (future)
class MAKIPOSApp extends ConsumerWidget {
  const MAKIPOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the router provider
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      // App information
      title: 'POS System',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Default to light theme

      // Router configuration
      routerConfig: router,

      // Builder for global overlays (loading, errors, etc.)
      builder: (context, child) {
        return MediaQuery(
          // Prevent system font scaling from breaking layouts
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
