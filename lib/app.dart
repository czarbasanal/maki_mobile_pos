import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/app_router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

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
          child: _OfflineBanner(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Displays a banner at the top when the device is offline.
class _OfflineBanner extends ConsumerWidget {
  final Widget child;

  const _OfflineBanner({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return Column(
      children: [
        if (isOffline)
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Icon(Icons.cloud_off, color: Colors.white, size: 20),
            backgroundColor: Colors.grey[700]!,
            content: const Text(
              'Offline — changes will sync automatically',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(child: child),
      ],
    );
  }
}
