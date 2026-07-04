import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Blocking "busy" overlay shown while a user-initiated async action runs —
/// the Contextual waiting dialog from the design handoff: a centered card
/// with a 56px primary progress ring, a verb-first title ("Saving…",
/// "Billing out…"), and an optional one-line subtitle. Composes on top of
/// skeleton loading: skeletons cover passive reads; this covers writes.
///
/// Don't construct directly — drive it via [WaitingDialog.runWithWaiting].
class AppWaitingDialog extends StatelessWidget {
  const AppWaitingDialog({super.key, required this.message, this.subtitle});

  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.lightCard,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: dark
            ? const BorderSide(color: AppColors.darkHairline)
            : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WaitingRing(dark: dark),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: dark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 212),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: dark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 56px indeterminate progress ring: a faint full-circle primary track with a
/// quarter arc in the primary color, spinning at 0.8s/turn linear — the
/// design's CSS border-top spinner, which Flutter's stock
/// [CircularProgressIndicator] (animated arc length) doesn't match.
class _WaitingRing extends StatefulWidget {
  const _WaitingRing({required this.dark});

  final bool dark;

  @override
  State<_WaitingRing> createState() => _WaitingRingState();
}

class _WaitingRingState extends State<_WaitingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size.square(56),
        painter: _RingPainter(
          trackColor: widget.dark
              ? const Color(0x2EE8B84C)
              : const Color(0x1F283E46),
          arcColor:
              widget.dark ? AppColors.primaryAccent : AppColors.brandSlate,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.trackColor, required this.arcColor});

  final Color trackColor;
  final Color arcColor;

  static const _stroke = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    canvas.drawCircle(center, radius, paint..color = trackColor);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3 * math.pi / 4, // quarter arc centered on top, like border-top-color
      math.pi / 2,
      false,
      paint..color = arcColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.trackColor != trackColor || oldDelegate.arcColor != arcColor;
}

/// Minimum time the dialog stays up so it never flashes on fast calls.
const _minWaitingDisplay = Duration(milliseconds: 300);

/// Runs an async [action] behind a blocking [AppWaitingDialog].
extension WaitingDialog on BuildContext {
  /// Shows the waiting dialog with [message] (and optional [subtitle]),
  /// awaits [action], then dismisses the dialog — returning the action's
  /// value (or rethrowing its error, so callers keep their own try/catch).
  /// The dialog stays up at least ~300ms so fast calls don't flash it.
  /// [action] must NOT navigate; the screen navigates after this returns.
  Future<T> runWithWaiting<T>(
    Future<T> Function() action, {
    required String message,
    String? subtitle,
  }) async {
    final navigator = Navigator.of(this, rootNavigator: true);
    final dark = Theme.of(this).brightness == Brightness.dark;
    showDialog<void>(
      context: this,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: AppDialog.scrimColor(dark),
      builder: (_) => PopScope(
        canPop: false,
        child: AppWaitingDialog(message: message, subtitle: subtitle),
      ),
    );
    final minDisplay = Future<void>.delayed(_minWaitingDisplay);
    try {
      return await action();
    } finally {
      await minDisplay;
      if (navigator.canPop()) navigator.pop();
    }
  }
}
