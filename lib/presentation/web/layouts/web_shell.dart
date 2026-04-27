import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/responsive/breakpoints.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/connectivity_provider.dart';
import 'package:maki_mobile_pos/presentation/web/widgets/web_sidebar.dart';
import 'package:maki_mobile_pos/presentation/web/widgets/web_top_bar.dart';

/// Persistent shell of the web admin app: sidebar (left) + top bar + content.
///
/// Wraps every authenticated route via `ShellRoute`. The actual page lives in
/// [child]; pages should use `WebPage` (not their own `Scaffold`) so they
/// don't duplicate chrome.
class WebShell extends ConsumerWidget {
  final Widget child;

  const WebShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    final extended = context.isExpanded;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Row(
        children: [
          WebSidebar(extended: extended),
          Expanded(
            child: Column(
              children: [
                if (isOffline) const _OfflineBanner(),
                const WebTopBar(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Breakpoints.maxContentWidth,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: Colors.grey[700],
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.white, size: 18),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Offline — changes will sync automatically',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
