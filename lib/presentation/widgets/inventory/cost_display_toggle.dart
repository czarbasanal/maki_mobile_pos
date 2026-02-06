import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/common_widgets.dart';

/// Toggle button for showing/hiding cost information.
///
/// Requires password verification to show costs.
class CostDisplayToggle extends ConsumerWidget {
  final bool showCost;
  final ValueChanged<bool> onToggle;

  const CostDisplayToggle({
    super.key,
    required this.showCost,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        showCost ? Icons.visibility : Icons.visibility_off,
        color: showCost ? Colors.green : null,
      ),
      tooltip: showCost ? 'Hide costs' : 'Show costs',
      onPressed: () => _handleToggle(context, ref),
    );
  }

  Future<void> _handleToggle(BuildContext context, WidgetRef ref) async {
    if (showCost) {
      // Hiding costs doesn't require password
      onToggle(false);
      return;
    }

    // Showing costs requires password verification
    final verified = await PasswordDialog.show(
      context: context,
      title: 'View Costs',
      subtitle: 'Enter your password to view cost information.',
      confirmButtonText: 'Verify',
      onVerify: (password) async {
        final authRepo = ref.read(authRepositoryProvider);
        return await authRepo.verifyPassword(password);
      },
    );

    if (verified) {
      onToggle(true);

      // Auto-hide after 5 minutes for security
      Future.delayed(const Duration(minutes: 5), () {
        if (showCost) {
          onToggle(false);
        }
      });
    }
  }
}

/// Inline widget for displaying cost with visibility control.
class CostDisplay extends ConsumerWidget {
  final double cost;
  final String costCode;
  final TextStyle? style;

  const CostDisplay({
    super.key,
    required this.cost,
    required this.costCode,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryStateProvider);
    final showCost = inventoryState.showCost;

    if (showCost) {
      return Text(
        '₱${cost.toStringAsFixed(2)}',
        style: style,
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: (style?.fontSize ?? 14) * 0.9,
            color: Colors.amber[700],
          ),
          const SizedBox(width: 4),
          Text(
            costCode,
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: 'monospace',
              color: Colors.amber[800],
            ),
          ),
        ],
      );
    }
  }
}
