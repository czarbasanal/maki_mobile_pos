import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';

/// Root-level blocking overlay for mid-session deactivation/deletion.
///
/// Mounted from the MaterialApp.router `builder` slot (above the router's
/// Navigator), so it covers every screen and can't be dismissed or navigated
/// away from. Watching the controller here also activates the whole watcher
/// chain (accountStatusProvider → controller) for the app's lifetime.
class AccountDeactivationOverlay extends ConsumerWidget {
  const AccountDeactivationOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDeactivationControllerProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        if (state.visible) ...[
          ModalBarrier(
            dismissible: false,
            color: dark ? const Color(0x99000000) : const Color(0x52111C1D),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: dark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.userX,
                            size: 22,
                            color: dark ? AppColors.errorOnDark : AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Account deactivated',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account has been deactivated by an '
                        'administrator. You will be signed out.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 14.5, height: 1.55),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.secondsLeft != null
                            ? 'Signing out in ${state.secondsLeft}s…'
                            : 'Signing out…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
