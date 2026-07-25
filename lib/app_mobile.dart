import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/mobile_router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/account_deactivation_overlay.dart';

/// Root widget of the mobile POS app (admin / staff / cashier).
class MAKIPOSMobileApp extends ConsumerStatefulWidget {
  const MAKIPOSMobileApp({super.key});

  @override
  ConsumerState<MAKIPOSMobileApp> createState() => _MAKIPOSMobileAppState();
}

class _MAKIPOSMobileAppState extends ConsumerState<MAKIPOSMobileApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The businessDayProvider timer is armed for the next local midnight, but
  // a device that sleeps through it misses the fire — this catches it on
  // resume so the business day is never stale after the app comes back to
  // the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(businessDayProvider.notifier).recheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionResetProvider); // clears session state on sign-out
    final router = ref.watch(mobileRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'POS System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: AccountDeactivationOverlay(
            child: _OfflineBanner(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

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
